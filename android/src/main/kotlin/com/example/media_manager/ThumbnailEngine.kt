package com.example.media_manager

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.media.ThumbnailUtils
import android.net.Uri
import android.os.Build
import androidx.exifinterface.media.ExifInterface
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap

/**
 * thumbnail را روی دیسک می‌نویسد و فقط «مسیر» را به Dart می‌دهد.
 * مزیت: هیچ بایت‌آرایه‌ای در heap نیتیو یا Dart انباشته نمی‌شود.
 */
class ThumbnailEngine(private val context: Context) {

    private val dir = File(context.cacheDir, "mm_thumbs").apply { mkdirs() }
    private val gate = Semaphore(MAX_CONCURRENT)
    private val inFlight = ConcurrentHashMap<String, Deferred<String?>>()

    companion object {
        private const val MAX_CONCURRENT = 4
        private const val QUALITY = 80
        private const val MAX_CACHE_BYTES = 96L * 1024 * 1024
    }

    suspend fun thumbnail(
        scope: CoroutineScope,
        uriOrPath: String,
        width: Int,
        height: Int,
        stamp: Long,
        isVideo: Boolean,
        isAudio: Boolean
    ): String? {
        val key = md5("$uriOrPath|$width|$height|$stamp")
        val cached = File(dir, "$key.jpg")
        if (cached.exists() && cached.length() > 0) return cached.absolutePath

        // dedupe: چند سلول لیست که هم‌زمان همان فایل را می‌خواهند
        val deferred = inFlight.getOrPut(key) {
            scope.async(Dispatchers.IO) {
                try {
                    gate.withPermit { generate(uriOrPath, width, height, isVideo, isAudio, cached) }
                } finally {
                    inFlight.remove(key)
                }
            }
        }
        return try { deferred.await() } catch (_: CancellationException) { null } catch (_: Throwable) { null }
    }

    private fun generate(
        uriOrPath: String, w: Int, h: Int,
        isVideo: Boolean, isAudio: Boolean, out: File
    ): String? {
        var bmp: Bitmap? = null
        try {
            bmp = when {
                isAudio -> albumArt(uriOrPath, w, h)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && uriOrPath.startsWith("content://") ->
                    loadThumbnailApi29(Uri.parse(uriOrPath), w, h)
                isVideo -> videoFrame(uriOrPath, w, h)
                else -> decodeSampled(uriOrPath, w, h)
            } ?: return null

            FileOutputStream(out).use { fos ->
                BufferedOutputStream(fos, 65536).use { bos ->
                    bmp.compress(Bitmap.CompressFormat.JPEG, QUALITY, bos)
                    bos.flush()
                }
                fos.fd.sync()
            }
            trimCache()
            return out.absolutePath
        } catch (e: Throwable) {
            out.delete()
            return null
        } finally {
            bmp?.recycle()   // ← نکته‌ای که در کد قبلی نبود
        }
    }

    /**
     * API 29+: از ImageDecoder استفاده می‌کند که مستقیماً روی native layer
     * کار می‌کند و verbose Skia logging ندارد.
     * اگر شکست خورد، fallback به decodeSampled.
     */
    private fun loadThumbnailApi29(uri: Uri, w: Int, h: Int): Bitmap? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        return try {
            val src = ImageDecoder.createSource(context.contentResolver, uri)
            ImageDecoder.decodeBitmap(src) { decoder, info, _ ->
                val sw = info.size.width
                val sh = info.size.height
                if (sw > w || sh > h) {
                    val scale = minOf(w.toFloat() / sw, h.toFloat() / sh)
                    decoder.setTargetSize(
                        (sw * scale).toInt().coerceAtLeast(1),
                        (sh * scale).toInt().coerceAtLeast(1)
                    )
                }
                // setPreferredColorSpace requires API 31 — skip to stay compatible
                decoder.setAllocator(ImageDecoder.ALLOCATOR_SOFTWARE)
            }
        } catch (_: Throwable) {
            // Fallback به مسیر BitmapFactory
            decodeSampled(uri.toString(), w, h)
        }
    }

    /** decode دو مرحله‌ای: هیچ‌وقت تصویر کامل ۴۸MP وارد heap نمی‌شود */
    private fun decodeSampled(pathOrUri: String, reqW: Int, reqH: Int): Bitmap? {
        fun open() = if (pathOrUri.startsWith("content://"))
            context.contentResolver.openInputStream(Uri.parse(pathOrUri))
        else File(pathOrUri).inputStream()

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        open()?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0) return null

        var sample = 1
        while (bounds.outWidth / (sample * 2) >= reqW && bounds.outHeight / (sample * 2) >= reqH) sample *= 2

        val opts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.RGB_565   // نصف حافظه برای thumbnail
        }
        val raw = open()?.use { BitmapFactory.decodeStream(it, null, opts) } ?: return null
        val scaled = ThumbnailUtils.extractThumbnail(
            raw, reqW, reqH, ThumbnailUtils.OPTIONS_RECYCLE_INPUT
        )
        return applyExif(pathOrUri, scaled)
    }

    private fun applyExif(pathOrUri: String, bmp: Bitmap): Bitmap {
        return try {
            val stream = if (pathOrUri.startsWith("content://"))
                context.contentResolver.openInputStream(Uri.parse(pathOrUri)) else File(pathOrUri).inputStream()
            val deg = stream?.use {
                when (ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                    else -> 0f
                }
            } ?: 0f
            if (deg == 0f) bmp else Bitmap.createBitmap(
                bmp, 0, 0, bmp.width, bmp.height, Matrix().apply { postRotate(deg) }, true
            ).also { if (it != bmp) bmp.recycle() }
        } catch (_: Throwable) { bmp }
    }

    private fun videoFrame(pathOrUri: String, w: Int, h: Int): Bitmap? {
        val r = MediaMetadataRetriever()
        return try {
            if (pathOrUri.startsWith("content://"))
                context.contentResolver.openFileDescriptor(Uri.parse(pathOrUri), "r")
                    ?.use { r.setDataSource(it.fileDescriptor) }
            else r.setDataSource(pathOrUri)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1)
                r.getScaledFrameAtTime(-1, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, w, h)
            else r.frameAtTime?.let { ThumbnailUtils.extractThumbnail(it, w, h, ThumbnailUtils.OPTIONS_RECYCLE_INPUT) }
        } catch (_: Throwable) { null } finally { runCatching { r.release() } }
    }

    private fun albumArt(pathOrUri: String, w: Int, h: Int): Bitmap? {
        val r = MediaMetadataRetriever()
        return try {
            if (pathOrUri.startsWith("content://"))
                context.contentResolver.openFileDescriptor(Uri.parse(pathOrUri), "r")
                    ?.use { r.setDataSource(it.fileDescriptor) }
            else r.setDataSource(pathOrUri)
            val bytes = r.embeddedPicture ?: return null
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            var s = 1
            while (bounds.outWidth / (s * 2) >= w) s *= 2
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size,
                BitmapFactory.Options().apply { inSampleSize = s; inPreferredConfig = Bitmap.Config.RGB_565 })
        } catch (_: Throwable) { null } finally { runCatching { r.release() } }
    }

    private fun trimCache() {
        val files = dir.listFiles() ?: return
        var total = files.sumOf { it.length() }
        if (total <= MAX_CACHE_BYTES) return
        files.sortedBy { it.lastModified() }.forEach {
            if (total <= MAX_CACHE_BYTES) return
            total -= it.length(); it.delete()
        }
    }

    fun clear() { dir.listFiles()?.forEach { it.delete() } }

    private fun md5(s: String) = MessageDigest.getInstance("MD5")
        .digest(s.toByteArray()).joinToString("") { "%02x".format(it) }
}
