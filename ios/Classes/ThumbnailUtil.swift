import Foundation
import UIKit
import Photos
import AVFoundation
import Kingfisher

class ThumbnailUtil {
    private let imageCache: ImageCache
    private let concurrentQueue: DispatchQueue
    private let maxCacheSize: Int
    
    init() {
        // Initialize optimized cache similar to Android implementation
        let memoryLimit = ProcessInfo.processInfo.physicalMemory / 8 // 1/8 of device memory
        self.maxCacheSize = Int(min(memoryLimit, 100 * 1024 * 1024)) // Max 100MB
        
        // Configure Kingfisher cache
        self.imageCache = ImageCache.default
        self.imageCache.memoryStorage.config.totalCostLimit = maxCacheSize
        self.imageCache.memoryStorage.config.countLimit = 100
        self.imageCache.diskStorage.config.sizeLimit = UInt(maxCacheSize * 2) // 2x memory for disk
        
        // Create concurrent queue for better performance
        self.concurrentQueue = DispatchQueue(label: "media_manager.thumbnail", 
                                           qos: .userInitiated, 
                                           attributes: .concurrent)
    }
    
    func getImagePreview(path: String, completion: @escaping (Result<Data, Error>) -> Void) {
        concurrentQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cacheKey = "preview_\(path)"
            
            // Check cache first
            if let cachedImage = self.imageCache.retrieveImageInMemoryCache(forKey: cacheKey) {
                if let imageData = cachedImage.jpegData(compressionQuality: 0.9) {
                    DispatchQueue.main.async {
                        completion(.success(imageData))
                    }
                    return
                }
            }
            
            // Load and process image
            guard let originalImage = UIImage(contentsOfFile: path) else {
                DispatchQueue.main.async {
                    completion(.failure(ThumbnailError.imageLoadFailed))
                }
                return
            }
            
            // Resize image for better performance
            let targetSize = CGSize(width: 800, height: 800)
            let resizedImage = self.resizeImage(originalImage, targetSize: targetSize)
            
            // Cache the processed image
            self.imageCache.store(resizedImage, forKey: cacheKey)
            
            // Compress and return
            if let imageData = resizedImage.jpegData(compressionQuality: 0.9) {
                DispatchQueue.main.async {
                    completion(.success(imageData))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(ThumbnailError.compressionFailed))
                }
            }
        }
    }
    
    func getVideoThumbnail(path: String, completion: @escaping (Result<Data, Error>) -> Void) {
        concurrentQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cacheKey = "video_\(path)"
            
            // Check cache first
            if let cachedImage = self.imageCache.retrieveImageInMemoryCache(forKey: cacheKey) {
                if let imageData = cachedImage.jpegData(compressionQuality: 0.8) {
                    DispatchQueue.main.async {
                        completion(.success(imageData))
                    }
                    return
                }
            }
            
            // Generate video thumbnail
            let url = URL(fileURLWithPath: path)
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 512, height: 512)
            
            let time = CMTime(seconds: 1, preferredTimescale: 60)
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let thumbnailImage = UIImage(cgImage: cgImage)
                
                // Cache the thumbnail
                self.imageCache.store(thumbnailImage, forKey: cacheKey)
                
                if let imageData = thumbnailImage.jpegData(compressionQuality: 0.8) {
                    DispatchQueue.main.async {
                        completion(.success(imageData))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(ThumbnailError.compressionFailed))
                    }
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
        return (memoryUsage, diskUsage)
    }
    
    // MARK: - Private Helper Methods
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
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