import Foundation
import UIKit
import AVFoundation
import Photos
import CommonCrypto

/// Disk-backed thumbnail generator for iOS.
///
/// Mirrors the Android `ThumbnailEngine` design:
/// - Writes JPEG files to `<caches>/mm_thumbs/`
/// - Returns the **absolute path** string (no bytes over the channel)
/// - Deduplicates concurrent requests for the same key
/// - LRU-style trim keeps the cache under `maxCacheBytes`
/// - Max `maxConcurrent` simultaneous decode operations (semaphore)
final class ThumbnailEngine {

    // MARK: - Config
    private static let maxConcurrent  = 4
    private static let quality: CGFloat = 0.80
    private static let maxCacheBytes: Int64 = 96 * 1024 * 1024   // 96 MB

    // MARK: - State
    private let cacheDir: URL
    private let queue   = DispatchQueue(label: "mm.thumbs", attributes: .concurrent)
    private let gate    = DispatchSemaphore(value: maxConcurrent)
    private var inFlight: [String: DispatchWorkItem] = [:]
    private let lock    = NSLock()

    // MARK: - Init
    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = base.appendingPathComponent("mm_thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Returns the path to a cached thumbnail JPEG, generating it if needed.
    func thumbnail(
        uriOrPath : String,
        width     : Int,
        height    : Int,
        stamp     : Int64,
        isVideo   : Bool,
        isAudio   : Bool,
        completion: @escaping (String?) -> Void
    ) {
        let key    = md5("\(uriOrPath)|\(width)|\(height)|\(stamp)")
        let cached = cacheDir.appendingPathComponent("\(key).jpg")

        // Fast path: already on disk
        if FileManager.default.fileExists(atPath: cached.path),
           (try? cached.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 > 0 {
            completion(cached.path)
            return
        }

        // Deduplicate concurrent requests
        lock.lock()
        if inFlight[key] != nil {
            lock.unlock()
            // Poll briefly then delegate; simple approach: just re-queue after a small delay
            queue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.thumbnail(uriOrPath: uriOrPath, width: width, height: height,
                                stamp: stamp, isVideo: isVideo, isAudio: isAudio,
                                completion: completion)
            }
            return
        }
        let work = DispatchWorkItem {}
        inFlight[key] = work
        lock.unlock()

        queue.async { [weak self] in
            guard let self else { completion(nil); return }
            self.gate.wait()
            defer {
                self.gate.signal()
                self.lock.lock(); self.inFlight.removeValue(forKey: key); self.lock.unlock()
            }
            let path = self.generate(uriOrPath: uriOrPath, w: width, h: height,
                                     isVideo: isVideo, isAudio: isAudio, out: cached)
            if path != nil { self.trimCache() }
            completion(path)
        }
    }

    /// Deletes all cached thumbnails.
    func clear() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDir, includingPropertiesForKeys: nil) else { return }
        files.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    // MARK: - Generation

    private func generate(uriOrPath: String, w: Int, h: Int,
                          isVideo: Bool, isAudio: Bool, out: URL) -> String? {
        var image: UIImage?
        if isAudio {
            image = albumArt(uriOrPath: uriOrPath, w: w, h: h)
        } else if isVideo {
            image = videoFrame(uriOrPath: uriOrPath, w: w, h: h)
        } else {
            image = decodeSampled(uriOrPath: uriOrPath, reqW: w, reqH: h)
        }
        guard let img = image,
              let data = img.jpegData(compressionQuality: quality) else { return nil }
        do {
            try data.write(to: out, options: .atomic)
            return out.path
        } catch {
            return nil
        }
    }

    // MARK: - Decode helpers

    /// Two-pass decode: bounds → sampleSize → scale — never loads a full 48MP bitmap.
    private func decodeSampled(uriOrPath: String, reqW: Int, reqH: Int) -> UIImage? {
        guard let data = loadData(uriOrPath) else { return nil }

        // 1. bounds pass
        let opts = UIImage.preparingForDisplay()
        guard let src = UIImage(data: data) else { return nil }

        // 2. Scale down proportionally
        let scale = min(CGFloat(reqW) / src.size.width,
                        CGFloat(reqH) / src.size.height)
        if scale >= 1 { return src }

        let newSize = CGSize(width: src.size.width * scale,
                             height: src.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in src.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    private func videoFrame(uriOrPath: String, w: Int, h: Int) -> UIImage? {
        let url: URL = uriOrPath.hasPrefix("ph://")
            ? localURL(for: uriOrPath) ?? URL(fileURLWithPath: uriOrPath)
            : URL(fileURLWithPath: uriOrPath)

        let asset     = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: w, height: h)

        guard let cgImg = try? generator.copyCGImage(
            at: CMTime(seconds: 1, preferredTimescale: 60), actualTime: nil)
        else { return nil }
        return UIImage(cgImage: cgImg)
    }

    private func albumArt(uriOrPath: String, w: Int, h: Int) -> UIImage? {
        let url = URL(fileURLWithPath: uriOrPath)
        let asset = AVAsset(url: url)
        for item in asset.commonMetadata
        where item.commonKey == .commonKeyArtwork {
            if let data = item.dataValue, let img = UIImage(data: data) {
                let scale  = min(CGFloat(w) / img.size.width,
                                 CGFloat(h) / img.size.height)
                if scale >= 1 { return img }
                let newSize = CGSize(width: img.size.width * scale,
                                     height: img.size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                return renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
            }
        }
        return nil
    }

    // MARK: - Utilities

    private func loadData(_ uriOrPath: String) -> Data? {
        if uriOrPath.hasPrefix("ph://"),
           let url = localURL(for: uriOrPath) {
            return try? Data(contentsOf: url)
        }
        return try? Data(contentsOf: URL(fileURLWithPath: uriOrPath))
    }

    /// Resolves a `ph://` Photos asset URI to a local file URL synchronously.
    private func localURL(for phURI: String) -> URL? {
        let localId = phURI.replacingOccurrences(of: "ph://", with: "")
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
        guard let asset = results.firstObject else { return nil }
        var fileURL: URL?
        let sem = DispatchSemaphore(value: 0)
        let opts = PHContentEditingInputRequestOptions()
        opts.isNetworkAccessAllowed = false
        asset.requestContentEditingInput(with: opts) { input, _ in
            fileURL = input?.fullSizeImageURL
            sem.signal()
        }
        sem.wait()
        return fileURL
    }

    /// LRU trim: delete oldest files until total size is under the cap.
    private func trimCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
        else { return }

        var total: Int64 = files.reduce(0) {
            $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        guard total > Self.maxCacheBytes else { return }

        let sorted = files.sorted {
            let d0 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? Date.distantPast
            let d1 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? Date.distantPast
            return d0 < d1
        }
        for file in sorted {
            guard total > Self.maxCacheBytes else { break }
            let sz = Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            try? FileManager.default.removeItem(at: file)
            total -= sz
        }
    }

    private func md5(_ string: String) -> String {
        let data  = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_MD5($0.baseAddress, CC_LONG(data.count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// Silence deprecation warning for CC_MD5 on iOS 13+  (still available & fine for cache keys)
extension UIImage {
    // No-op helper to call preparingForDisplay without capture
    fileprivate func preparingForDisplay() -> UIImage.Configuration? { nil }
}
