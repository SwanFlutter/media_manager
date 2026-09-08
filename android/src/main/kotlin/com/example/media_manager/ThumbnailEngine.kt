package com.example.media_manager

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.media.ThumbnailUtils
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import android.util.Size
import androidx.exifinterface.media.ExifInterface
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap

class ThumbnailEngine(private val context: Context) {

    private val dir = File(context.cacheDir, "mm_thumbs").apply { mkdirs() }
    private val gate = Semaphore(MAX_CONCURRENT)
    private val inFlight = ConcurrentHashMap<String, Deferred<String?>>()

    companion object {
        private const val TAG = "MM_Thumb"
        private const val MAX_CONCURRENT = 4
        private const val QUALITY = 85
        private const val MAX_CACHE_BYTES = 128L * 1024 * 1024
    }

    // ─── Public entry point ───────────────────────────────────────────────

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

        val deferred = inFlight.getOrPut(key) {
            scope.async(Dispatchers.IO) {
                try {
                    gate.withPermit { generate(uriOrPath, width, height, isVideo, isAudio, cached) }
                } finally {
                    inFlight.remove(key)
                }
            }
        }
        return try {
            deferred.await()
        } catch (_: CancellationException) { null }
          catch (e: Throwable) {
            Log.e(TAG, "thumbnail error: ${e.javaClass.simpleName}: ${e.message}")
            null
        }
    }

    // ─── Core generator ───────────────────────────────────────────────────

    private fun generate(
        uriOrPath: String, w: Int, h: Int,
        isVideo: Boolean, isAudio: Boolean, out: File
    ): String? {
        val bmp: Bitmap = when {
            isAudio -> albumArt(uriOrPath, w, h)
            isVideo -> videoFrame(uriOrPath, w, h)
            else    -> imageBitmap(uriOrPath, w, h)
        } ?: return null

        return try {
            saveBitmap(bmp, out)
        } finally {
            bmp.recycle()
        }
    }

    private fun saveBitmap(bmp: Bitmap, out: File): String? {
        return try {
            FileOutputStream(out).use { fos ->
                BufferedOutputStream(fos, 65_536).use { bos ->
                    bmp.compress(Bitmap.CompressFormat.JPEG, QUALITY, bos)
                    bos.flush()
                }
                // NOTE: fd.sync() intentionally omitted — throws SyncFailedException
                // on cacheDir (tmpfs/virtual FS) on many Android devices. flush() is sufficient.
            }
            if (out.length() == 0L) { out.delete(); return null }
            trimCache()
            out.absolutePath
        } catch (e: Throwable) {
            Log.e(TAG, "saveBitmap failed: ${e.javaClass.simpleName}: ${e.message}")
            out.delete()
            null
        }
    }

    // ─── Image strategies ─────────────────────────────────────────────────

    private fun imageBitmap(uriOrPath: String, w: Int, h: Int): Bitmap? {
        val isContent = uriOrPath.startsWith("content://")
        val uri = if (isContent) Uri.parse(uriOrPath) else null

        // Strategy 1: ContentResolver.loadThumbnail (API 29+) — fastest, no full decode
        if (uri != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tryLoadThumbnail(uri, w, h)?.let { return it }
        }

        // Strategy 2: Legacy MediaStore.Images.Thumbnails (API < 29)
        if (uri != null && Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            tryLegacyImageThumbnail(uri, w, h)?.let { return it }
        }

        // Strategy 3: BitmapFactory two-pass decode (universal fallback)
        return decodeSampled(uriOrPath, w, h)
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.Q)
    private fun tryLoadThumbnail(uri: Uri, w: Int, h: Int): Bitmap? {
        return try {
            context.contentResolver.loadThumbnail(uri, Size(w, h), null)
        } catch (_: Throwable) { null }
    }

    private fun tryLegacyImageThumbnail(uri: Uri, w: Int, h: Int): Bitmap? {
        return try {
            val id = uri.lastPathSegment?.toLongOrNull() ?: return null
            @Suppress("DEPRECATION")
            val bmp = MediaStore.Images.Thumbnails.getThumbnail(
                context.contentResolver, id,
                MediaStore.Images.Thumbnails.MINI_KIND, null
            ) ?: return null
            ThumbnailUtils.extractThumbnail(bmp, w, h, ThumbnailUtils.OPTIONS_RECYCLE_INPUT)
        } catch (_: Throwable) { null }
    }

    /**
     * Two-pass BitmapFactory decode: pass 1 measures dimensions to calculate
     * the correct inSampleSize, pass 2 decodes at reduced resolution.
     * Never loads the full image into heap.
     */
    private fun decodeSampled(pathOrUri: String, reqW: Int, reqH: Int): Bitmap? {
        fun open() = try {
            if (pathOrUri.startsWith("content://"))
                context.contentResolver.openInputStream(Uri.parse(pathOrUri))
            else
                File(pathOrUri).inputStream()
        } catch (_: Throwable) { null }

        // Pass 1: measure
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        open()?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        // Calculate power-of-two sample size
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= reqW &&
               bounds.outHeight / (sample * 2) >= reqH) sample *= 2

        // Pass 2: decode at reduced size
        val opts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.RGB_565  // half memory vs ARGB_8888
        }
        val raw = open()?.use { BitmapFactory.decodeStream(it, null, opts) } ?: return null
        val scaled = ThumbnailUtils.extractThumbnail(raw, reqW, reqH, ThumbnailUtils.OPTIONS_RECYCLE_INPUT)
        return applyExifRotation(pathOrUri, scaled)
    }

    // ─── Video ────────────────────────────────────────────────────────────

    private fun videoFrame(uriOrPath: String, w: Int, h: Int): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            if (uriOrPath.startsWith("content://")) {
                context.contentResolver
                    .openFileDescriptor(Uri.parse(uriOrPath), "r")
                    ?.use { retriever.setDataSource(it.fileDescriptor) }
            } else {
                retriever.setDataSource(uriOrPath)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                retriever.getScaledFrameAtTime(-1, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, w, h)
            } else {
                @Suppress("DEPRECATION")
                retriever.frameAtTime?.let {
                    ThumbnailUtils.extractThumbnail(it, w, h, ThumbnailUtils.OPTIONS_RECYCLE_INPUT)
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "videoFrame error: ${e.javaClass.simpleName}: ${e.message}")
            null
        } finally {
            runCatching { retriever.release() }
        }
    }

    // ─── Audio ────────────────────────────────────────────────────────────

    private fun albumArt(uriOrPath: String, w: Int, h: Int): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            if (uriOrPath.startsWith("content://")) {
                context.contentResolver
                    .openFileDescriptor(Uri.parse(uriOrPath), "r")
                    ?.use { retriever.setDataSource(it.fileDescriptor) }
            } else {
                retriever.setDataSource(uriOrPath)
            }
            val bytes = retriever.embeddedPicture ?: return null
            val boundsOpts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, boundsOpts)
            var s = 1
            while (boundsOpts.outWidth / (s * 2) >= w) s *= 2
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size,
                BitmapFactory.Options().apply {
                    inSampleSize = s
                    inPreferredConfig = Bitmap.Config.RGB_565
                })
        } catch (e: Throwable) {
            Log.e(TAG, "albumArt error: ${e.javaClass.simpleName}: ${e.message}")
            null
        } finally {
            runCatching { retriever.release() }
        }
    }

    // ─── EXIF rotation ────────────────────────────────────────────────────

    private fun applyExifRotation(pathOrUri: String, bmp: Bitmap): Bitmap {
        val degrees: Float = try {
            val orientation = if (pathOrUri.startsWith("content://")) {
                context.contentResolver.openInputStream(Uri.parse(pathOrUri))?.use {
                    ExifInterface(it).getAttributeInt(
                        ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
                } ?: ExifInterface.ORIENTATION_NORMAL
            } else {
                ExifInterface(pathOrUri).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            }
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90  -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } catch (_: Throwable) { 0f }

        if (degrees == 0f) return bmp
        return Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height,
            Matrix().apply { postRotate(degrees) }, true
        ).also { if (it !== bmp) bmp.recycle() }
    }

    // ─── Cache management ─────────────────────────────────────────────────

    private fun trimCache() {
        val files = dir.listFiles() ?: return
        var total = files.sumOf { it.length() }
        if (total <= MAX_CACHE_BYTES) return
        files.sortedBy { it.lastModified() }.forEach { f ->
            if (total <= MAX_CACHE_BYTES) return
            total -= f.length(); f.delete()
        }
    }

    fun clear() { dir.listFiles()?.forEach { it.delete() } }

    // ─── Utilities ────────────────────────────────────────────────────────

    private fun md5(input: String): String =
        MessageDigest.getInstance("MD5")
            .digest(input.toByteArray())
            .joinToString("") { "%02x".format(it) }
}
