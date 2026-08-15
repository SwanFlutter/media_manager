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
    private func queryPage(type: String, extensions: [String],
                           page: Int, pageSize: Int) -> [[String: Any?]] {
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
        let opts = PHFetchOptions()
        switch type {
        case "image":  return PHAsset.fetchAssets(with: .image,  options: opts).count
        case "video":  return PHAsset.fetchAssets(with: .video,  options: opts).count
        case "audio":  return 0
        default:       return PHAsset.fetchAssets(with: opts).count
        }
    }

    private func assetToMap(_ asset: PHAsset) -> [String: Any?] {
        let stamp = Int64((asset.modificationDate?.timeIntervalSince1970 ?? 0) * 1000)
        var mimeType: String? = nil
        if let uti = asset.value(forKey: "uniformTypeIdentifier") as? String {
            mimeType = mimeTypeFromUTI(uti)
        }
        return [
            "id"           : 0,                                // no integer id on iOS
            "uri"          : "ph://\(asset.localIdentifier)",
            "name"         : (asset.value(forKey: "filename") as? String) ?? "",
            "size"         : 0,                                // not cheaply available
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
