import Flutter
import UIKit
import Photos
import AVFoundation
import UniformTypeIdentifiers
import MobileCoreServices

public final class MediaManagerPlugin: NSObject, FlutterPlugin {

    // MARK: - State
    private let engine     = ThumbnailEngine()
    private let ioQueue    = DispatchQueue(label: "mm.ios.io", qos: .userInitiated,
                                           attributes: .concurrent)
    private let main       = DispatchQueue.main

    // MARK: - Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel  = FlutterMethodChannel(name: "media_manager",
                                            binaryMessenger: registrar.messenger())
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
            safe.success("iOS " + UIDevice.current.systemVersion)

        // ── Permissions ───────────────────────────────────────────────────
        case "hasStoragePermission":
            let status = authStatus()
            if #available(iOS 14, *) {
                safe.success(status == .authorized || status == .limited)
            } else {
                safe.success(status == .authorized)
            }

        case "hasAllFilesAccess":
            // iOS has no MANAGE_EXTERNAL_STORAGE concept; sandbox scan always works.
            safe.success(true)

        case "requestStoragePermission":
            requestPhotoPermission(safe)

        case "openAllFilesAccessSettings":
            // No-op on iOS
            safe.success(true)

        // ── Paginated media query ──────────────────────────────────────────
        case "getMediaPage":
            let type      = args["type"] as? String ?? "any"
            let exts      = args["extensions"] as? [String] ?? []
            let page      = args["page"] as? Int ?? 0
            let pageSize  = max(1, min(args["pageSize"] as? Int ?? 100, 500))
            ioQueue.async { [weak self] in
                guard let self else { return }
                let items = self.queryPage(type: type, extensions: exts,
                                           page: page, pageSize: pageSize)
                safe.success(items)
            }

        case "getMediaCount":
            let type = args["type"] as? String ?? "any"
            let exts = args["extensions"] as? [String] ?? []
            ioQueue.async { [weak self] in
                guard let self else { return }
                safe.success(self.queryCount(type: type, extensions: exts))
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
                           ?? FileManager.default.urls(for: .documentDirectory,
                                                       in: .userDomainMask)[0].path
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

    // MARK: - PHPhotoLibrary query

    /// Archive / document extensions resolved from the app sandbox on iOS
    /// (the Photos library never contains zips, APKs, code files, …).
    private static let archiveExts: Set<String> = [
        // Compressed archives
        "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "tbz2",
        "xz", "txz", "lz", "lzma", "zst", "tzst",
        // App packages
        "ipa", "apk", "aab",
        // Linux/Unix packages
        "deb", "rpm",
        // Java archives
        "jar", "war",
        // Comic / eBook archives
        "cbz", "cbr", "epub", "mobi",
        // Python / misc
        "whl", "egg",
    ]
    private static let docExts: Set<String> = [
        // Office documents
        "pdf", "doc", "docx", "dot", "dotx", "docm",
        "xls", "xlsx", "xlsm", "xlsb",
        "ppt", "pptx", "pptm", "ppsx",
        // Apple iWork
        "pages", "numbers", "key",
        // OpenDocument
        "odt", "ods", "odp",
        // Plain text / markup
        "txt", "rtf", "md", "markdown", "csv", "tsv",
        "html", "htm", "xml", "json",
        "log", "yaml", "yml", "ini", "cfg",
        // eBooks
        "epub", "mobi", "azw3", "fb2",
        // Archives (documents tab also shows archives)
        "zip", "rar", "7z", "tar", "gz",
        // App packages
        "apk", "ipa", "xapk", "apks",
        // Windows / cross-platform executables and installers
        "exe", "msi", "msix", "appx", "jar",
        "bat", "cmd", "ps1", "vbs", "sh",
        // Disk images
        "iso", "img", "dmg", "vhd", "vhdx",
        // Databases
        "db", "sqlite", "sqlite3", "mdb", "accdb",
    ]

    private func authStatus() -> PHAuthorizationStatus {
        if #available(iOS 14, *) {
            return PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
        return PHPhotoLibrary.authorizationStatus()
    }

    private func requestPhotoPermission(_ safe: SafeResult) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                safe.success(status == .authorized || status == .limited)
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                safe.success(status == .authorized)
            }
        }
    }

    /// Returns paginated [MediaItem] maps from the Photos library.
    /// Document / archive types (and custom extension filters) are resolved by
    /// scanning the app sandbox instead — the Photos library never holds zips,
    /// PDFs from Files.app, code files, etc.
    private func queryPage(type: String, extensions: [String],
                           page: Int, pageSize: Int) -> [[String: Any?]] {
        let extsLower = Set(extensions.map {
            $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }.filter { !$0.isEmpty })

        if type == "document" || type == "archive" || !extsLower.isEmpty {
            let allowed = allowedFileExts(type: type, extra: extsLower)
            let files = scanSandbox(allowed: allowed)
            let sorted = files.sorted {
                let d0 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate) ?? Date.distantPast
                let d1 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate) ?? Date.distantPast
                return d0 > d1
            }
            let from = page * pageSize
            guard from < sorted.count else { return [] }
            let slice = sorted[from ..< min(from + pageSize, sorted.count)]
            return slice.map { urlToFileMap($0) }
        }

        let opts     = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]

        let assets: PHFetchResult<PHAsset>
        switch type {
        case "image":
            assets = PHAsset.fetchAssets(with: .image, options: opts)
        case "video":
            assets = PHAsset.fetchAssets(with: .video, options: opts)
        case "audio":
            // Photos library has no audio; return empty
            return []
        default:
            assets = PHAsset.fetchAssets(with: opts)
        }

        let total = assets.count
        let from  = page * pageSize
        guard from < total else { return [] }
        let to    = min(from + pageSize, total) - 1

        var out = [[String: Any?]]()
        out.reserveCapacity(to - from + 1)

        assets.enumerateObjects(at: IndexSet(from...to), options: []) { asset, _, _ in
            out.append(self.assetToMap(asset))
        }
        return out
    }

    private func queryCount(type: String, extensions: [String]) -> Int {
        let extsLower = Set(extensions.map {
            $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }.filter { !$0.isEmpty })

        if type == "document" || type == "archive" || !extsLower.isEmpty {
            return scanSandbox(allowed: allowedFileExts(type: type, extra: extsLower)).count
        }

        let opts = PHFetchOptions()
        switch type {
        case "image":  return PHAsset.fetchAssets(with: .image,  options: opts).count
        case "video":  return PHAsset.fetchAssets(with: .video,  options: opts).count
        case "audio":  return 0
        default:       return PHAsset.fetchAssets(with: opts).count
        }
    }

    /// Extension allow-set for sandbox scanning (nil = accept every file).
    private func allowedFileExts(type: String, extra: Set<String>) -> Set<String>? {
        var base: Set<String>?
        switch type {
        case "document": base = Self.docExts
        case "archive":  base = Self.archiveExts
        default:         base = nil
        }
        if extra.isEmpty { return base }
        return base.map { $0.union(extra) } ?? extra
    }

    /// Walks the sandbox directories that can legitimately hold user files
    /// (Documents, Downloads, Caches, tmp) with a hidden-file skip.
    /// Budget caps the total entries visited to avoid blocking on huge sandboxes.
    private func scanSandbox(allowed: Set<String>?) -> [URL] {
        let fm = FileManager.default
        let dirs: [URL] = {
            var list: [URL] = []
            for d: FileManager.SearchPathDirectory in [
                .documentDirectory, .downloadsDirectory, .cachesDirectory
            ] {
                list += fm.urls(for: d, in: .userDomainMask)
            }
            list.append(fm.temporaryDirectory)
            return list
        }()
        var out    = [URL]()
        var budget = 50_000          // max entries visited (not max results)
        for dir in dirs {
            guard let en = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let u as URL in en {
                guard budget > 0 else { return out }
                budget -= 1
                let rv = try? u.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                if rv?.isDirectory == true { continue }
                guard let sz = rv?.fileSize, sz > 0 else { continue }
                let ext = u.pathExtension.lowercased()
                if allowed == nil || allowed!.contains(ext) {
                    out.append(u)
                }
            }
        }
        return out
    }

    /// Maps a sandbox file URL into the MediaItem dictionary shape.
    private func urlToFileMap(_ url: URL) -> [String: Any?] {
        let rv = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let ext = url.pathExtension.lowercased()
        return [
            "id"           : 0,
            "uri"          : url.path,
            "name"         : url.lastPathComponent,
            "size"         : Int64(rv?.fileSize ?? 0),
            "dateModified" : Int64((rv?.contentModificationDate?.timeIntervalSince1970 ?? 0) * 1000),
            "mediaType"    : 0,
            "mimeType"     : mimeFromFileExtension(ext),
            "path"         : url.path,
            "width"        : 0,
            "height"       : 0,
            "duration"     : 0,
        ]
    }

    private func mimeFromFileExtension(_ ext: String) -> String? {
        guard !ext.isEmpty else { return nil }
        if #available(iOS 14, *) {
            return UTType(filenameExtension: ext)?.preferredMIMEType
        }
        guard let mime = UTTypeCopyPreferredTagWithClass(ext as CFString,
                                                         kUTTagClassMIMEType)?
                .takeRetainedValue() else { return nil }
        return mime as String
    }

    private func assetToMap(_ asset: PHAsset) -> [String: Any?] {
        let stamp = Int64((asset.modificationDate?.timeIntervalSince1970 ?? 0) * 1000)

        // Resolve MIME from the asset's UTI
        var mimeType: String? = nil
        if let uti = asset.value(forKey: "uniformTypeIdentifier") as? String {
            mimeType = mimeTypeFromUTI(uti)
        }

        // Resolve display name: prefer the private "filename" KVC key (available on
        // most iOS versions), then fall back to the resource's preferred filename
        // from PHAssetResource, then to the localIdentifier last component.
        let name: String = {
            if let fn = asset.value(forKey: "filename") as? String, !fn.isEmpty {
                return fn
            }
            // PHAssetResource gives us the original filename without a sync wait
            let resources = PHAssetResource.assetResources(for: asset)
            if let r = resources.first(where: {
                $0.type == .photo || $0.type == .video || $0.type == .audio ||
                $0.type == .fullSizePhoto || $0.type == .fullSizeVideo
            }) {
                let n = r.originalFilename
                if !n.isEmpty { return n }
            }
            if let r = resources.first {
                let n = r.originalFilename
                if !n.isEmpty { return n }
            }
            // Last resort: derive something from the localIdentifier
            return asset.localIdentifier.components(separatedBy: "/").first ?? asset.localIdentifier
        }()

        return [
            "id"           : 0,
            "uri"          : "ph://\(asset.localIdentifier)",
            "name"         : name,
            "size"         : 0,                                // not cheaply available from PHAsset
            "dateModified" : stamp,
            "mediaType"    : asset.mediaType.rawValue,
            "mimeType"     : mimeType,
            "width"        : asset.pixelWidth,
            "height"       : asset.pixelHeight,
            "duration"     : Int64(asset.duration * 1000),
        ]
    }

    /// Resolves a UTI to its preferred MIME type, supporting iOS 13 and later.
    private func mimeTypeFromUTI(_ uti: String) -> String? {
        if #available(iOS 14, *) {
            return UTType(uti)?.preferredMIMEType
        }
        guard let mime = UTTypeCopyPreferredTagWithClass(uti as CFString,
                                                         kUTTagClassMIMEType)?.takeRetainedValue() else {
            return nil
        }
        return mime as String
    }

    // MARK: - Directory helpers

    private func publicDirectories() -> [[String: String]] {
        let fm = FileManager.default
        let dirs: [(String, FileManager.SearchPathDirectory)] = [
            ("Documents",  .documentDirectory),
            ("Caches",     .cachesDirectory),
            ("Downloads",  .downloadsDirectory),
        ]
        return dirs.compactMap { name, dir in
            guard let url = fm.urls(for: dir, in: .userDomainMask).first else { return nil }
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
            if d0 != d1 { return d0 }         // directories first
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
}

// MARK: - SafeResult

/// Ensures the FlutterResult callback is called exactly once and always on the main thread.
private final class SafeResult {
    private var delegate: FlutterResult?
    private let lock = NSLock()

    init(_ result: @escaping FlutterResult) { self.delegate = result }

    func success(_ value: Any?) { post { $0(value) } }
    func error(_ code: String, _ msg: String?, _ details: Any?) {
        post { $0(FlutterError(code: code, message: msg, details: details)) }
    }
    func notImplemented() { post { $0(FlutterMethodNotImplemented) } }

    private func post(_ block: @escaping (FlutterResult) -> Void) {
        lock.lock()
        guard let d = delegate else { lock.unlock(); return }
        delegate = nil
        lock.unlock()
        if Thread.isMainThread { block(d) }
        else { DispatchQueue.main.async { block(d) } }
    }
}
