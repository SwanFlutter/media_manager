import Foundation
import Cocoa
import AVFoundation
import Kingfisher

class ThumbnailUtil {
    private let imageCache: ImageCache
    private let concurrentQueue: DispatchQueue
    private let maxCacheSize: Int
    
    init() {
        // Initialize optimized cache similar to iOS implementation
        let memoryLimit = ProcessInfo.processInfo.physicalMemory / 8 // 1/8 of device memory
        self.maxCacheSize = Int(min(memoryLimit, 100 * 1024 * 1024)) // Max 100MB
        
        // Configure Kingfisher cache for macOS
        self.imageCache = ImageCache.default
        self.imageCache.memoryStorage.config.totalCostLimit = maxCacheSize
        self.imageCache.memoryStorage.config.countLimit = 100
        self.imageCache.diskStorage.config.sizeLimit = UInt(maxCacheSize * 2) // 2x memory for disk
        
        // Create concurrent queue for better performance
        self.concurrentQueue = DispatchQueue(label: "media_manager.thumbnail.macos", 
                                           qos: .userInitiated, 
                                           attributes: .concurrent)
    }
    
    func getImagePreview(path: String, completion: @escaping (Result<Data, Error>) -> Void) {
        concurrentQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cacheKey = "preview_\(path)"
            
            // Check cache first
            if let cachedImage = self.imageCache.retrieveImageInMemoryCache(forKey: cacheKey) {
                if let imageData = self.convertImageToData(cachedImage) {
                    DispatchQueue.main.async {
                        completion(.success(imageData))
                    }
                    return
                }
            }
            
            // Load and process image
            guard let originalImage = NSImage(contentsOfFile: path) else {
                DispatchQueue.main.async {
                    completion(.failure(ThumbnailError.imageLoadFailed))
                }
                return
            }
            
            // Resize image for better performance
            let targetSize = NSSize(width: 300, height: 300)
            let resizedImage = self.resizeImage(originalImage, targetSize: targetSize)
            
            // Cache the processed image
            self.imageCache.store(resizedImage, forKey: cacheKey)
            
            // Convert to data
            guard let imageData = self.convertImageToData(resizedImage) else {
                DispatchQueue.main.async {
                    completion(.failure(ThumbnailError.compressionFailed))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(imageData))
            }
        }
    }
    
    func getVideoThumbnail(path: String, completion: @escaping (Result<Data, Error>) -> Void) {
        concurrentQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cacheKey = "video_\(path)"
            
            // Check cache first
            if let cachedImage = self.imageCache.retrieveImageInMemoryCache(forKey: cacheKey) {
                if let imageData = self.convertImageToData(cachedImage) {
                    DispatchQueue.main.async {
                        completion(.success(imageData))
                    }
                    return
                }
            }
            
            let url = URL(fileURLWithPath: path)
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 300, height: 300)
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: CMTime.zero, actualTime: nil)
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                
                // Cache the thumbnail
                self.imageCache.store(nsImage, forKey: cacheKey)
                
                guard let imageData = self.convertImageToData(nsImage) else {
                    DispatchQueue.main.async {
                        completion(.failure(ThumbnailError.compressionFailed))
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    completion(.success(imageData))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(ThumbnailError.thumbnailGenerationFailed(error)))
                }
            }
        }
    }
    
    func clearCache() {
        imageCache.clearMemoryCache()
        imageCache.clearDiskCache()
    }
    
    func getCacheInfo() -> (memoryUsage: Int, diskUsage: UInt) {
        let memoryUsage = imageCache.memoryStorage.totalCost
        let diskUsage = imageCache.diskStorage.totalSize
        return (memoryUsage: memoryUsage, diskUsage: diskUsage)
    }
    
    private func resizeImage(_ image: NSImage, targetSize: NSSize) -> NSImage {
        let sourceSize = image.size
        let widthRatio = targetSize.width / sourceSize.width
        let heightRatio = targetSize.height / sourceSize.height
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledSize = NSSize(width: sourceSize.width * scaleFactor, 
                               height: sourceSize.height * scaleFactor)
        
        let resizedImage = NSImage(size: scaledSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: scaledSize))
        resizedImage.unlockFocus()
        
        return resizedImage
    }
    
    private func convertImageToData(_ image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
    }
}

// MARK: - Error Types
enum ThumbnailError: Error {
    case imageLoadFailed
    case compressionFailed
    case thumbnailGenerationFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .imageLoadFailed:
            return "Failed to load image"
        case .compressionFailed:
            return "Failed to compress image"
        case .thumbnailGenerationFailed(let error):
            return "Failed to generate thumbnail: \(error.localizedDescription)"
        }
    }
}