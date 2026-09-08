package com.example.media_manager

import android.content.ContentResolver
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.provider.MediaStore
import android.webkit.MimeTypeMap

class MediaStoreScanner(private val context: Context) {

    enum class Type { IMAGE, VIDEO, AUDIO, DOCUMENT, ANY }

    private val filesUri: Uri =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        else
            MediaStore.Files.getContentUri("external")

    private val projection: Array<String>
        get() {
            val base = mutableListOf(
                MediaStore.Files.FileColumns._ID,
                MediaStore.Files.FileColumns.DISPLAY_NAME,
                MediaStore.Files.FileColumns.SIZE,
                MediaStore.Files.FileColumns.DATE_MODIFIED,
                MediaStore.Files.FileColumns.MIME_TYPE,
                MediaStore.Files.FileColumns.MEDIA_TYPE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                base += MediaStore.Files.FileColumns.WIDTH
                base += MediaStore.Files.FileColumns.HEIGHT
                base += MediaStore.Files.FileColumns.DURATION
            }
            return base.toTypedArray()
        }

    /** صفحه‌بندی واقعی در سطح SQLite — نه در حافظه */
    fun queryPage(
        type: Type,
        extensions: List<String>,
        offset: Int,
        limit: Int,
        signal: CancellationSignal?
    ): List<Map<String, Any?>> {
        val (selection, args) = buildSelection(type, extensions)
        val sort = "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC"
        val out = ArrayList<Map<String, Any?>>(limit)

        runQuery(selection, args, sort, limit, offset, signal)?.use { c ->
            val idIdx    = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameIdx  = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeIdx  = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dateIdx  = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
            val mimeIdx  = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
            val mediaIdx = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
            val wIdx     = c.getColumnIndex("width")
            val hIdx     = c.getColumnIndex("height")
            val dIdx     = c.getColumnIndex("duration")

            while (c.moveToNext()) {
                val id        = c.getLong(idIdx)
                val mediaType = c.getInt(mediaIdx)
                val uri       = buildMediaUri(id, mediaType)
                out.add(
                    mapOf(
                        "id"           to id,
                        "uri"          to uri,
                        "name"         to (c.getStringOrNull(nameIdx) ?: ""),
                        "size"         to c.getLong(sizeIdx),
                        "dateModified" to c.getLong(dateIdx) * 1000L,
                        "mimeType"     to c.getStringOrNull(mimeIdx),
                        "mediaType"    to mediaType,
                        "width"        to if (wIdx >= 0) c.getInt(wIdx)  else 0,
                        "height"       to if (hIdx >= 0) c.getInt(hIdx)  else 0,
                        "duration"     to if (dIdx >= 0) c.getLong(dIdx) else 0L
                    )
                )
            }
        }
        return out
    }

    fun count(type: Type, extensions: List<String>, signal: CancellationSignal?): Int {
        val (selection, args) = buildSelection(type, extensions)
        return context.contentResolver.query(
            filesUri, arrayOf(MediaStore.Files.FileColumns._ID), selection, args, null, signal
        )?.use { it.count } ?: 0
    }

    private fun runQuery(
        selection: String, args: Array<String>, sort: String,
        limit: Int, offset: Int, signal: CancellationSignal?
    ): Cursor? {
        val cr = context.contentResolver
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bundle = Bundle().apply {
                putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, args)
                putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, sort)
                putInt(ContentResolver.QUERY_ARG_LIMIT, limit)
                putInt(ContentResolver.QUERY_ARG_OFFSET, offset)
            }
            cr.query(filesUri, projection, bundle, signal)
        } else {
            cr.query(filesUri, projection, selection, args, "$sort LIMIT $limit OFFSET $offset", signal)
        }
    }

    private fun buildSelection(type: Type, extensions: List<String>): Pair<String, Array<String>> {
        val where = StringBuilder()
        val args = ArrayList<String>()

        when (type) {
            Type.IMAGE -> {
                where.append("${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?")
                args.add(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString())
            }
            Type.VIDEO -> {
                where.append("${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?")
                args.add(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString())
            }
            Type.AUDIO -> {
                where.append("${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?")
                args.add(MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO.toString())
            }
            Type.DOCUMENT, Type.ANY -> {
                // حداکثر ۹۰۰ آرگومان (سقف SQLite ~۹۹۹)
                val exts = extensions.map { it.lowercase().removePrefix(".") }.distinct().take(300)
                if (exts.isEmpty()) {
                    where.append("1=1")
                } else {
                    val mimes = exts.mapNotNull {
                        MimeTypeMap.getSingleton().getMimeTypeFromExtension(it)
                    }.distinct()
                    val parts = ArrayList<String>()
                    if (mimes.isNotEmpty()) {
                        parts.add("${MediaStore.Files.FileColumns.MIME_TYPE} IN (${mimes.joinToString(",") { "?" }})")
                        args.addAll(mimes)
                    }
                    // پسوندهایی که MIME ندارند (dart, kt, ...) با LIKE پارامتری
                    val noMime = exts.filter { MimeTypeMap.getSingleton().getMimeTypeFromExtension(it) == null }
                    noMime.forEach {
                        parts.add("${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?")
                        args.add("%.$it")
                    }
                    where.append(parts.joinToString(" OR ", prefix = "(", postfix = ")"))
                }
            }
        }
        // فایل‌های ناقص/صفر و پوشه‌ها را حذف کن
        where.append(" AND ${MediaStore.Files.FileColumns.SIZE} > 0")
        return where.toString() to args.toTypedArray()
    }

    private fun Cursor.getStringOrNull(i: Int) = if (isNull(i)) null else getString(i)

    /**
     * Builds the correct typed MediaStore URI for the given row ID and media type.
     *
     * Using typed URIs (Images.Media, Video.Media, Audio.Media) instead of the
     * generic Files URI is required for ContentResolver.loadThumbnail (API 29+)
     * and legacy MediaStore.Images.Thumbnails (API < 29) to work correctly.
     *
     * Falls back to the generic Files URI for documents and unknown types.
     */
    private fun buildMediaUri(id: Long, mediaType: Int): String {
        val baseUri = when (mediaType) {
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                    MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
                else
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI

            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                    MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
                else
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI

            MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                    MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
                else
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI

            else -> filesUri
        }
        return Uri.withAppendedPath(baseUri, id.toString()).toString()
    }
}
