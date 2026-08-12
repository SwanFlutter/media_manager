import FlutterMacOS
import AppKit
import AVFoundation

public final class MediaManagerPlugin: NSObject, FlutterPlugin {

    // MARK: - State
    private let engine  = ThumbnailEngine()
    private let ioQueue = DispatchQueue(label: "mm.macos.io", qos: .userInitiated,
                                        attributes: .concurrent)

    // MARK: - Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel  = FlutterMethodChannel(name: "media_manager",
                                            binaryMessenger: registrar.messenger)
        let instance = MediaManagerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - Method dispatch

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let safe = SafeResult(result)
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {

        // ── Platform ──────────────────────────────────────────────────────
        case "getPlatformVersion":
            safe.success("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)

        // ── Permissions ───────────────────────────────────────────────────
        case "hasStoragePermission":
            // macOS sandbox: assume access to sandbox container is always available.
            // For files outside the sandbox the user grants via open-panel — return true
            // optimistically so callers can proceed and let the OS block if needed.
            safe.success(true)

        case "requestStoragePermission":
            // Present NSOpenPanel to let the user grant access to a directory.
            // Returns true once the user picks a folder (access is implicitly granted).
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.canChooseDirectories  = true
                panel.canChooseFiles        = false
                panel.allowsMultipleSelection = false
                panel.message = "Select a folder to grant media access"
                panel.prompt  = "Grant Access"
                safe.success(panel.runModal() == .OK)
            }

        case "openAllFilesAccessSettings":
            // No MANAGE_ALL_FILES equivalent on macOS — no-op.
            safe.success(true)

        // ── Paginated media query ──────────────────────────────────────────
        case "getMediaPage":
            let path     = args["path"] as? String
                           ?? FileManager.default.homeDirectoryForCurrentUser.path
            let type     = args["type"]      as? String ?? "any"
            let exts     = args["extensions"] as? [String] ?? []
            let page     = args["page"]      as? Int ?? 0
            let pageSize = max(1, min(args["pageSize"] as? Int ?? 100, 500))
            ioQueue.async { [weak self] in
                guard let self else { return }
                do {
                    let items = try self.scanMedia(root: path, type: type,
                                                   extensions: exts,
                                                   page: page, pageSize: pageSize)
                    safe.success(items)
                } catch {
                    safe.error("QUERY_ERROR", error.localizedDescription, nil)
                }
            }

        case "getMediaCount":
            let path = args["path"] as? String
                       ?? FileManager.default.homeDirectoryForCurrentUser.path
            let type = args["type"] as? String ?? "any"
            let exts = args["extensions"] as? [String] ?? []
            ioQueue.async { [weak self] in
                guard let self else { return }
                let count = (try? self.countMedia(root: path, type: type,
                                                  extensions: exts)) ?? 0
                safe.success(count)
            }

        // ── Thumbnails ────────────────────────────────────────────────────
        case "getThumbnail":
            guard let src = (args["uri"] as? String) ?? (args["path"] as? String) else {
                safe.error("INVALID_ARGUMENT", "uri/path required", nil); return
            }
            let w     = args["width"]  as? Int ?? 256
            let h     = args["height"] as? Int ?? w
            let stamp = (args["dateModified"] as? NSNumber)?.int64Value ?? 0
            let kind  = args["kind"]   as? String ?? "image"
            engine.thumbnail(uriOrPath: src, width: w, height: h, stamp: stamp,
                             isVideo: kind == "video", isAudio: kind == "audio") { path in
                safe.success(path)
            }

        case "clearThumbnailCache":
            ioQueue.async { [weak self] in
                self?.engine.clear()
                safe.success(true)
            }

        // ── Directory helpers ─────────────────────────────────────────────
        case "getDirectories":
            ioQueue.async { [weak self] in
                guard let self else { return }
                safe.success(self.publicDirectories())
            }

        case "getDirectoryContents":
            let path     = args["path"] as? String
                           ?? FileManager.default.homeDirectoryForCurrentUser.path
            let page     = args["page"]     as? Int ?? 0
            let pageSize = max(1, min(args["pageSize"] as? Int ?? 200, 1000))
            ioQueue.async { [weak self] in
                guard let self else { return }
                do {
                    let items = try self.listDir(path: path, page: page, pageSize: pageSize)
                    safe.success(items)
                } catch {
                    safe.error("FILE_ACCESS_ERROR", error.localizedDescription, nil)
                }
            }

        default:
            safe.notImplemented()
        }
    }

    // MARK: - Media scan (file-system based on macOS)

    private static let imageExts = Set(["jpg","jpeg","png","gif","bmp","webp",
                                        "tiff","tif","heic","heif","avif","raw","cr2","nef"])
    private static let videoExts = Set(["mp4","mov","m4v","avi","mkv","wmv",
                                        "flv","webm","3gp","mpg","mpeg","ts"])
    private static let audioExts = Set(["mp3","wav","m4a","aac","ogg","flac",
                                        "opus","aiff","alac","wma","dsf"])
    private static let docExts   = Set(["pdf","doc","docx","txt","rtf","odt",
                                        "xls","xlsx","ppt","pptx","pages","numbers",
                                        "key","epub","md","csv","json","xml","html"])

    private func allowedExtensions(type: String, extra: [String]) -> Set<String>? {
        var base: Set<String>?
        switch type {
        case "image":    base = Self.imageExts
        case "video":    base = Self.videoExts
        case "audio":    base = Self.audioExts
        case "document": base = Self.docExts
        default:         base = nil    // nil = accept all
        }
        if extra.isEmpty { return base }
        let extras = Set(extra.map { $0.lowercased().trimmingCharacters(in: .init(charactersIn: ".")) })
        return base.map { $0.union(extras) } ?? extras
    }

    /// Recursively collects matching files (depth-limited), then paginates.
    private func scanMedia(root: String, type: String, extensions: [String],
                           page: Int, pageSize: Int) throws -> [[String: Any?]] {
        let allowed  = allowedExtensions(type: type, extra: extensions)
        var collected = [URL]()
        try walk(url: URL(fileURLWithPath: root), allowed: allowed,
                 depth: 0, maxDepth: 8, out: &collected)

        // Sort newest-first by modification date
        let fm = FileManager.default
        let sorted = collected.sorted {
            let d0 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? Date.distantPast
            let d1 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? Date.distantPast
            return d0 > d1
        }

        let from = page * pageSize
        guard from < sorted.count else { return [] }
        let slice = sorted[from ..< min(from + pageSize, sorted.count)]
        var index = 0
        return slice.map { u -> [String: Any?] in
            index += 1
            let rv       = try? u.resourceValues(forKeys:
                                [.fileSizeKey, .contentModificationDateKey])
            let size     = Int64(rv?.fileSize ?? 0)
            let modified = Int64((rv?.contentModificationDate?.timeIntervalSince1970 ?? 0) * 1000)
            let ext      = u.pathExtension.lowercased()
            let mime     = mimeType(for: ext)
            return [
                "id"           : index,
                "uri"          : u.path,
                "name"         : u.lastPathComponent,
                "size"         : size,
                "dateModified" : modified,
                "mediaType"    : mediaTypeInt(ext: ext),
                "mimeType"     : mime,
                "width"        : 0,
                "height"       : 0,
                "duration"     : 0,
            ]
        }
    }

    private func countMedia(root: String, type: String, extensions: [String]) throws -> Int {
        let allowed = allowedExtensions(type: type, extra: extensions)
        var collected = [URL]()
        try walk(url: URL(fileURLWithPath: root), allowed: allowed,
                 depth: 0, maxDepth: 8, out: &collected)
        return collected.count
    }

    private func walk(url: URL, allowed: Set<String>?, depth: Int, maxDepth: Int,
                      out: inout [URL]) throws {
        guard depth <= maxDepth else { return }
        let fm       = FileManager.default
        guard fm.isReadableFile(atPath: url.path) else { return }
        let keys     : [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
        let contents = try fm.contentsOfDirectory(at: url,
                                                  includingPropertiesForKeys: keys,
                                                  options: [.skipsHiddenFiles])
        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                try walk(url: item, allowed: allowed, depth: depth + 1,
                         maxDepth: maxDepth, out: &out)
            } else {
                let ext = item.pathExtension.lowercased()
                if allowed == nil || allowed!.contains(ext) {
                    let sz = Int64((try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                    if sz > 0 { out.append(item) }
                }
            }
        }
    }

    // MARK: - Directory helpers

    private func publicDirectories() -> [[String: String]] {
        let fm   = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let named: [(String, URL)] = [
            ("Home",      home),
            ("Desktop",   home.appendingPathComponent("Desktop")),
            ("Documents", home.appendingPathComponent("Documents")),
            ("Downloads", home.appendingPathComponent("Downloads")),
            ("Pictures",  home.appendingPathComponent("Pictures")),
            ("Movies",    home.appendingPathComponent("Movies")),
            ("Music",     home.appendingPathComponent("Music")),
        ]
        return named.compactMap { name, url in
            guard fm.fileExists(atPath: url.path) else { return nil }
            return ["name": name, "path": url.path]
        }
    }

    private func listDir(path: String, page: Int, pageSize: Int) throws -> [[String: Any]] {
        let fm  = FileManager.default
        let url = URL(fileURLWithPath: path)
        guard fm.fileExists(atPath: path) else {
            throw NSError(domain: "MediaManager", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Path not found: \(path)"])
        }
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
        let contents = try fm.contentsOfDirectory(at: url,
                                                  includingPropertiesForKeys: keys,
                                                  options: [.skipsHiddenFiles])
        let sorted = contents.sorted {
            let d0 = (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let d1 = (try? $1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if d0 != d1 { return d0 }
            return $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased()
        }
        let from = page * pageSize
        guard from < sorted.count else { return [] }
        let slice = sorted[from ..< min(from + pageSize, sorted.count)]

        return slice.map { u -> [String: Any] in
            let rv       = try? u.resourceValues(forKeys: Set(keys))
            let isDir    = rv?.isDirectory ?? false
            let size     = Int64(rv?.fileSize ?? 0)
            let modified = Int64((rv?.contentModificationDate?.timeIntervalSince1970 ?? 0) * 1000)
            return [
                "name"        : u.lastPathComponent,
                "path"        : u.path,
                "isDirectory" : isDir,
                "size"        : size,
                "dateModified": modified,
                "extension"   : isDir ? "" : u.pathExtension.lowercased(),
            ]
        }
    }

    // MARK: - Helpers

    private func mimeType(for ext: String) -> String? {
        let map: [String: String] = [
            "jpg":"image/jpeg","jpeg":"image/jpeg","png":"image/png",
            "gif":"image/gif","webp":"image/webp","bmp":"image/bmp",
            "tiff":"image/tiff","tif":"image/tiff","heic":"image/heic",
            "mp4":"video/mp4","mov":"video/quicktime","m4v":"video/x-m4v",
            "avi":"video/avi","mkv":"video/x-matroska","webm":"video/webm",
            "mp3":"audio/mpeg","wav":"audio/wav","m4a":"audio/m4a",
            "aac":"audio/aac","flac":"audio/flac","ogg":"audio/ogg",
            "pdf":"application/pdf","doc":"application/msword",
            "docx":"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls":"application/vnd.ms-excel",
            "xlsx":"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "ppt":"application/vnd.ms-powerpoint",
            "pptx":"application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "txt":"text/plain","html":"text/html","css":"text/css",
            "json":"application/json","xml":"application/xml",
            "zip":"application/zip","rar":"application/x-rar-compressed",
            "7z":"application/x-7z-compressed",
        ]
        return map[ext]
    }

    /// Maps file extension to Android MediaStore.Files.FileColumns.MEDIA_TYPE constants.
    private func mediaTypeInt(ext: String) -> Int {
        if Self.imageExts.contains(ext) { return 1 }   // MEDIA_TYPE_IMAGE
        if Self.videoExts.contains(ext) { return 3 }   // MEDIA_TYPE_VIDEO
        if Self.audioExts.contains(ext) { return 2 }   // MEDIA_TYPE_AUDIO
        return 0                                        // MEDIA_TYPE_NONE
    }
}

// MARK: - SafeResult

/// Guarantees FlutterResult is called exactly once, always on the main thread.
private final class SafeResult {
    private var delegate: FlutterResult?
    private let lock = NSLock()

    init(_ result: @escaping FlutterResult) { self.delegate = result }

    func success(_ value: Any?)                                    { post { $0(value) } }
    func error(_ code: String, _ msg: String?, _ details: Any?)   {
        post { $0(FlutterError(code: code, message: msg, details: details)) }
    }
    func notImplemented()                                          { post { $0(FlutterMethodNotImplemented) } }

    private func post(_ block: @escaping (FlutterResult) -> Void) {
        lock.lock()
        guard let d = delegate else { lock.unlock(); return }
        delegate = nil
        lock.unlock()
        if Thread.isMainThread { block(d) }
        else { DispatchQueue.main.async { block(d) } }
    }
}
