import Foundation
import AppKit
import AVFoundation
import CommonCrypto

/// Disk-backed thumbnail generator for macOS.
///
/// Design mirrors Android `ThumbnailEngine` and iOS `ThumbnailEngine`:
/// - Writes JPEG files to `<caches>/mm_thumbs/`
/// - Returns the **absolute path** string — zero bytes cross the channel
/// - Deduplicates concurrent requests for the same cache key
/// - LRU-style trim keeps the cache under `maxCacheBytes` (96 MB)
/// - At most `maxConcurrent` (4) simultaneous decode operations
final class ThumbnailEngine {

    // MARK: - Config
    private static let maxConcurrent: Int   = 4
    private static let quality: CGFloat     = 0.80
    private static let maxCacheBytes: Int64 = 96 * 1024 * 1024   // 96 MB

    // MARK: - State
    private let cacheDir : URL
    private let queue    = DispatchQueue(label: "mm.macos.thumbs", attributes: .concurrent)
    private let gate     = DispatchSemaphore(value: maxConcurrent)
    private var inFlight : [String: Bool] = [:]
    private let lock     = NSLock()

    // MARK: - Init
    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = base.appendingPathComponent("mm_thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir,
                                                  withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Generates (or returns a cached) thumbnail and calls `completion` with
    /// the absolute path to the on-disk JPEG, or `nil` on failure.
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

        // Deduplicate
        lock.lock()
        if inFlight[key] != nil {
            lock.unlock()
            queue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.thumbnail(uriOrPath: uriOrPath, width: width, height: height,
                                stamp: stamp, isVideo: isVideo, isAudio: isAudio,
                                completion: completion)
            }
            return
        }
        inFlight[key] = true
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
            at: cacheDir, includingPropertiesForKeys: nil)
        else { return }
        files.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    // MARK: - Generation

    private func generate(uriOrPath: String, w: Int, h: Int,
                          isVideo: Bool, isAudio: Bool, out: URL) -> String? {
        var image: NSImage?
        if isAudio {
            image = albumArt(path: uriOrPath, w: w, h: h)
        } else if isVideo {
            image = videoFrame(path: uriOrPath, w: w, h: h)
        } else {
            image = decodeSampled(path: uriOrPath, reqW: w, reqH: h)
        }
        guard let img = image, let data = jpegData(from: img, quality: Self.quality) else {
            return nil
        }
        do {
            try data.write(to: out, options: .atomic)
            return out.path
        } catch {
            return nil
        }
    }

    // MARK: - Decode helpers

    /// Scale-down decode so we never load a full-resolution RAW into memory.
    private func decodeSampled(path: String, reqW: Int, reqH: Int) -> NSImage? {
        guard let src = NSImage(contentsOfFile: path) else { return nil }
        let scale = min(CGFloat(reqW) / src.size.width,
                        CGFloat(reqH) / src.size.height)
        if scale >= 1 { return src }
        let newSize = NSSize(width: src.size.width * scale,
                             height: src.size.height * scale)
        return resized(src, to: newSize)
    }

    private func videoFrame(path: String, w: Int, h: Int) -> NSImage? {
        let url       = URL(fileURLWithPath: path)
        let asset     = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: w, height: h)
        guard let cgImg = try? generator.copyCGImage(
            at: CMTime(seconds: 1, preferredTimescale: 60), actualTime: nil)
        else { return nil }
        return NSImage(cgImage: cgImg,
                       size: NSSize(width: cgImg.width, height: cgImg.height))
    }

    private func albumArt(path: String, w: Int, h: Int) -> NSImage? {
        let asset = AVAsset(url: URL(fileURLWithPath: path))
        for item in asset.commonMetadata
        where item.commonKey == .commonKeyArtwork {
            if let data = item.dataValue, let img = NSImage(data: data) {
                let scale = min(CGFloat(w) / img.size.width,
                                CGFloat(h) / img.size.height)
                if scale >= 1 { return img }
                return resized(img, to: NSSize(width: img.size.width * scale,
                                               height: img.size.height * scale))
            }
        }
        return nil
    }

    // MARK: - NSImage utilities

    private func resized(_ image: NSImage, to size: NSSize) -> NSImage {
        let result = NSImage(size: size)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1.0)
        result.unlockFocus()
        return result
    }

    private func jpegData(from image: NSImage, quality: CGFloat) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep  = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg,
                                  properties: [.compressionFactor: quality])
    }

    // MARK: - Cache management

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

    // MARK: - MD5 (cache key only)
    private func md5(_ string: String) -> String {
        let data   = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_MD5($0.baseAddress, CC_LONG(data.count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
