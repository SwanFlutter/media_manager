package com.example.media_manager

import android.content.Context
import android.graphics.Bitmap
import android.util.LruCache
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy
import com.bumptech.glide.request.RequestOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.ThreadPoolExecutor

/**
 * Utility class for generating optimized thumbnails for images and videos
 * Based on photo_manager's ThumbnailUtil implementation
 */
class ThumbnailUtil(
    private val context: Context,
    private val cache: LruCache<String, ByteArray>,
    private val executor: ThreadPoolExecutor
) {
    
    companion object {
        private const val IMAGE_TARGET_SIZE = 800
        private const val VIDEO_TARGET_WIDTH = 512
        private const val VIDEO_TARGET_HEIGHT = 384
        private const val COMPRESSION_QUALITY = 90
    }

    /**
     * Generate optimized image preview using Glide
     */
    suspend fun getImagePreview(imagePath: String): ByteArray? = withContext(Dispatchers.IO) {
        try {
            val cacheKey = "img_${imagePath}_${IMAGE_TARGET_SIZE}"
            
            // Check cache first
            cache.get(cacheKey)?.let { return@withContext it }
            
            // Validate file exists
            val file = File(imagePath)
            if (!file.exists() || !file.canRead()) {
                return@withContext null
            }

            // Use Glide for optimized loading
            val bitmap = Glide.with(context)
                .asBitmap()
                .load(file)
                .apply(
                    RequestOptions()
                        .override(IMAGE_TARGET_SIZE, IMAGE_TARGET_SIZE)
                        .centerCrop()
                        .diskCacheStrategy(DiskCacheStrategy.RESOURCE)
                )
                .submit()
                .get()

            // Compress to byte array
            val byteArray = compressBitmapToByteArray(bitmap)
            
            // Cache the result
            cache.put(cacheKey, byteArray)
            
            byteArray
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Generate optimized video thumbnail using Glide
     */
    suspend fun getVideoThumbnail(videoPath: String): ByteArray? = withContext(Dispatchers.IO) {
        try {
            val cacheKey = "vid_${videoPath}_${VIDEO_TARGET_WIDTH}x${VIDEO_TARGET_HEIGHT}"
            
            // Check cache first
            cache.get(cacheKey)?.let { return@withContext it }
            
            // Validate file exists
            val file = File(videoPath)
            if (!file.exists() || !file.canRead()) {
                return@withContext null
            }

            // Use Glide for video thumbnail extraction
            val bitmap = Glide.with(context)
                .asBitmap()
                .load(file)
                .apply(
                    RequestOptions()
                        .override(VIDEO_TARGET_WIDTH, VIDEO_TARGET_HEIGHT)
                        .centerCrop()
                        .frame(0) // Get first frame
                        .diskCacheStrategy(DiskCacheStrategy.RESOURCE)
                )
                .submit()
                .get()

            // Compress to byte array
            val byteArray = compressBitmapToByteArray(bitmap)
            
            // Cache the result
            cache.put(cacheKey, byteArray)
            
            byteArray
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Compress bitmap to byte array with optimized quality
     */
    private fun compressBitmapToByteArray(bitmap: Bitmap): ByteArray {
        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, COMPRESSION_QUALITY, outputStream)
        return outputStream.toByteArray()
    }

    /**
     * Clear all cached thumbnails
     */
    fun clearCache() {
        cache.evictAll()
    }

    /**
     * Get cache statistics
     */
    fun getCacheInfo(): Map<String, Any> {
        return mapOf(
            "size" to cache.size(),
            "maxSize" to cache.maxSize(),
            "hitCount" to cache.hitCount(),
            "missCount" to cache.missCount(),
            "evictionCount" to cache.evictionCount()
        )
    }
}