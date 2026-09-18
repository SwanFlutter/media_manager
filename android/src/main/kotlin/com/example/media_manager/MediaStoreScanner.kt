package com.example.media_manager

import android.content.ContentResolver
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import java.io.File
import java.util.ArrayDeque

class MediaStoreScanner(private val context: Context) {

    enum class Type { IMAGE, VIDEO, AUDIO, DOCUMENT, ARCHIVE, ANY }

    // ─── MediaStore URIs ──────────────────────────────────────────────────

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
                MediaStore.Files.FileColumns.MEDIA_TYPE,
                MediaStore.Files.FileColumns.DATA
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                base += MediaStore.Files.FileColumns.WIDTH
                base += MediaStore.Files.FileColumns.HEIGHT
                base += MediaStore.Files.FileColumns.DURATION
            }
            return base.toTypedArray()
        }

    // ─── Public API ───────────────────────────────────────────────────────

    /** Real SQL-level pagination — nothing is loaded into memory beyond the page. */
    fun queryPage(
        type: Type,
        extensions: List<String>,
        offset: Int,
        limit: Int,
        signal: CancellationSignal?
    ): List<Map<String, Any?>> {
        if (needsFsScan(type, extensions)) {
            // MediaStore does not index archives / custom formats on many OEM
            // devices, so merge a file-system scan with whatever the DB returns.
            val merged = mergedRows(type, extensions, signal)
            if (offset >= merged.size) return emptyList()
            return merged.subList(offset, minOf(offset + limit, merged.size))
        }

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
            val dataIdx  = c.getColumnIndex(MediaStore.Files.FileColumns.DATA)
            val wIdx     = c.getColumnIndex("width")
            val hIdx     = c.getColumnIndex("height")
            val dIdx     = c.getColumnIndex("duration")

            while (c.moveToNext()) {
                val id        = c.getLong(idIdx)
                val mediaType = c.getInt(mediaIdx)
                val uri       = buildMediaUri(id, mediaType)

                // Prefer MediaStore DISPLAY_NAME; fall back to the URI's last
                // path segment so the UI never shows a blank filename.
                val rawName = c.getStringOrNull(nameIdx)
                val name    = if (!rawName.isNullOrBlank()) {
                    rawName
                } else {
                    val seg = uri.substringAfterLast('/')
                    Uri.decode(seg).takeIf { it.isNotBlank() } ?: ""
                }

                out.add(
                    mapOf(
                        "id"           to id,
                        "uri"          to uri,
                        "name"         to name,
                        "size"         to c.getLong(sizeIdx),
                        "dateModified" to c.getLong(dateIdx) * 1000L,
                        "mimeType"     to c.getStringOrNull(mimeIdx),
                        "mediaType"    to mediaType,
                        "path"         to (if (dataIdx >= 0) c.getStringOrNull(dataIdx) else null),
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
        if (needsFsScan(type, extensions)) {
            return mergedRows(type, extensions, signal).size
        }
        val (selection, args) = buildSelection(type, extensions)
        return context.contentResolver.query(
            filesUri,
            arrayOf(MediaStore.Files.FileColumns._ID),
            selection, args, null, signal
        )?.use { it.count } ?: 0
    }

    // ─── Query execution ──────────────────────────────────────────────────

    private fun runQuery(
        selection: String,
        args: Array<String>,
        sort: String,
        limit: Int,
        offset: Int,
        signal: CancellationSignal?
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
            cr.query(filesUri, projection, selection, args,
                "$sort LIMIT $limit OFFSET $offset", signal)
        }
    }

    // ─── Selection builder ────────────────────────────────────────────────

    private fun buildSelection(
        type: Type,
        extensions: List<String>
    ): Pair<String, Array<String>> {
        val colType = MediaStore.Files.FileColumns.MEDIA_TYPE
        val colMime = MediaStore.Files.FileColumns.MIME_TYPE
        val colName = MediaStore.Files.FileColumns.DISPLAY_NAME
        val where   = StringBuilder()
        val args    = ArrayList<String>()

        when (type) {
            Type.IMAGE -> {
                where.append("$colType = ?")
                args.add(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString())
            }
            Type.VIDEO -> {
                where.append("$colType = ?")
                args.add(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString())
            }
            Type.AUDIO -> {
                where.append("$colType = ?")
                args.add(MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO.toString())
            }
            Type.DOCUMENT -> {
                val callerExts = extensions
                    .map { it.lowercase().removePrefix(".") }
                    .distinct()
                    .take(300)

                if (callerExts.isEmpty()) {
                    // Built-in MIME whitelist + name-LIKE fallback (MediaStore
                    // often stores NULL mime for zips/archives) and block media rows
                    val placeholders = DOCUMENT_MIMES.joinToString(",") { "?" }
                    where.append("($colMime IN ($placeholders)")
                    args.addAll(DOCUMENT_MIMES)
                    for (ext in DOCUMENT_FALLBACK_EXTS) {
                        where.append(" OR $colName LIKE ?")
                        args.add("%.$ext")
                    }
                    where.append(")")
                    where.append(" AND $colType NOT IN (?,?,?)")
                    args.add(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString())
                    args.add(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString())
                    args.add(MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO.toString())
                } else {
                    buildExtensionFilter(callerExts, colMime, colName, where, args)
                    where.append(" AND $colType NOT IN (?,?,?)")
                    args.add(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString())
                    args.add(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString())
                    args.add(MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO.toString())
                }
            }
            Type.ARCHIVE -> {
                val targets = if (extensions.isEmpty()) ARCHIVE_EXTS
                              else normalizedExts(extensions).toSet()
                val likeParts = ArrayList<String>()
                val msArgs    = ArrayList<String>()
                val mimeSet   = LinkedHashSet<String>()
                val mimeMap   = MimeTypeMap.getSingleton()
                for (ext in targets) {
                    likeParts.add("$colName LIKE ?")
                    msArgs.add("%.$ext")
                    mimeMap.getMimeTypeFromExtension(ext)?.let { mimeSet.add(it) }
                }
                if (mimeSet.isNotEmpty()) {
                    likeParts.add("$colMime IN (${mimeSet.joinToString(",") { "?" }})")
                    msArgs.addAll(mimeSet)
                }
                where.append(likeParts.joinToString(" OR ", prefix = "(", postfix = ")"))
                args.addAll(msArgs)
            }
            Type.ANY -> {
                val callerExts = extensions
                    .map { it.lowercase().removePrefix(".") }
                    .distinct()
                    .take(300)
                if (callerExts.isEmpty()) {
                    where.append("1=1")
                } else {
                    buildExtensionFilter(callerExts, colMime, colName, where, args)
                }
            }
        }

        // Exclude zero-byte files and directory entries
        where.append(" AND ${MediaStore.Files.FileColumns.SIZE} > 0")
        return where.toString() to args.toTypedArray()
    }

    /**
     * Builds MIME IN (…) or DISPLAY_NAME LIKE '%.ext' clauses.
     * Extensions in [ALWAYS_LIKE_EXTS] (source code, configs, etc.) or those
     * without a system MIME mapping are always matched via LIKE to avoid the
     * MIME database mapping them to unexpected types on some devices.
     *
     * Extensions that *do* have a MIME mapping get BOTH a `mime IN (...)` term
     * and a `name LIKE '%.ext'` term, because MediaStore frequently stores a
     * NULL or vendor-specific MIME (archives, custom formats) which would
     * otherwise make the file invisible.
     */
    private fun buildExtensionFilter(
        exts: List<String>,
        mimeCol: String,
        nameCol: String,
        where: StringBuilder,
        args: ArrayList<String>
    ) {
        val mimeMap  = MimeTypeMap.getSingleton()
        val parts    = ArrayList<String>()
        val likeExts = exts.filter { it in ALWAYS_LIKE_EXTS || mimeMap.getMimeTypeFromExtension(it) == null }
        val mimeExts = exts - likeExts.toSet()
        val mimes    = mimeExts.mapNotNull { mimeMap.getMimeTypeFromExtension(it) }.distinct()

        if (mimes.isNotEmpty()) {
            parts.add("$mimeCol IN (${mimes.joinToString(",") { "?" }})")
            args.addAll(mimes)
        }
        // Always match by extension name too so files with a missing/wrong MIME
        // (common for zip/rar/7z and any custom format) still show up.
        for (ext in exts) {
            parts.add("$nameCol LIKE ?")
            args.add("%.$ext")
        }
        if (parts.isNotEmpty()) {
            where.append(parts.joinToString(" OR ", prefix = "(", postfix = ")"))
        } else {
            where.append("1=1")
        }
    }

    // ─── Helpers ─────────────────────────────────────────────────────────

    /**
     * MediaStore only indexes files in well-known locations on many OEM ROMs
     * (and prunes archives / custom formats entirely on some Android 13+
     * devices), so a Documents / custom-extension query can silently miss
     * files that exist on disk. For those cases we merge a bounded
     * file-system walk into the MediaStore result.
     */
    private fun needsFsScan(type: Type, extensions: List<String>): Boolean {
        // MediaStore simply does not index archives / many custom formats on
        // Android 13+ and on most OEM ROMs, so these categories must be
        // resolved by walking external storage directly.
        return when (type) {
            Type.DOCUMENT, Type.ARCHIVE -> true
            Type.ANY -> normalizedExts(extensions).isNotEmpty()
            else -> false
        }
    }

    private fun normalizedExts(extensions: List<String>): List<String> =
        extensions.map { it.lowercase().removePrefix(".") }.filter { it.isNotEmpty() }.distinct()

    private fun mergedRows(
        type: Type,
        extensions: List<String>,
        signal: CancellationSignal?
    ): List<Map<String, Any?>> {
        val (selection, args) = buildSelection(type, extensions)
        val rows = ArrayList<Map<String, Any?>>()

        // If the MediaStore half fails on an OEM ROM, still return the FS scan.
        runCatching {
            runQuery(
                selection, args,
                "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC",
                Int.MAX_VALUE, 0, signal
            )?.use { rows.addAll(cursorToMaps(it)) }
        }

        val exts = normalizedExts(extensions)
        val fsExts: Set<String> = when {
            exts.isNotEmpty() -> exts.toSet()
            type == Type.DOCUMENT -> DOCUMENT_FALLBACK_EXTS.toSet()
            type == Type.ARCHIVE -> ARCHIVE_EXTS
            else -> emptySet()
        }

        if (fsExts.isNotEmpty()) {
            // A file may be indexed by MediaStore *and* found by the walk.
            // Register every MediaStore row under both its real path and its
            // name|size key so the FS pass never adds a duplicate.
            val seen = HashSet<String>(rows.size * 2 + 256)
            for (row in rows) {
                (row["path"] as? String)?.let { seen.add(it) }
                seen.add("${row["name"]}|${row["size"]}")
            }
            for (f in fsCandidates(fsExts, type == Type.DOCUMENT)) {
                val name = f.name
                if (name in seen) continue
                if (!seen.add(f.absolutePath)) continue
                seen.add("$name|${f.length()}")
                val ext = name.substringAfterLast('.', "").lowercase()
                val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
                rows.add(
                    mapOf(
                        "id"           to -(System.identityHashCode(f).toLong() and 0x7FFFFFFF),
                        "uri"          to Uri.fromFile(f).toString(),
                        "name"         to name,
                        "size"         to f.length(),
                        "dateModified" to f.lastModified(),
                        "mimeType"     to mime,
                        "mediaType"    to MediaStore.Files.FileColumns.MEDIA_TYPE_NONE,
                        "path"         to f.absolutePath,
                        "width"        to 0,
                        "height"       to 0,
                        "duration"     to 0L
                    )
                )
            }
            rows.sortByDescending { (it["dateModified"] as Number).toLong() }
        }
        return rows
    }

    /**
     * Depth-bounded walk over every accessible external-storage volume.
     * Skips dot-dirs, private Android/{data,obb} trees and caps total files
     * so a pathological SD-card can never lock the query.
     */
    private fun fsCandidates(exts: Set<String>, excludeMedia: Boolean): List<File> {
        val out = ArrayList<File>()
        val roots = LinkedHashSet<String>()
        runCatching { Environment.getExternalStorageDirectory()?.absolutePath }
            .getOrNull()?.let { roots.add(it) }
        runCatching {
            for (d in context.getExternalFilesDirs(null)) {
                d?.absolutePath?.substringBeforeLast("/Android/")?.let { roots.add(it) }
            }
        }
        val mimeMap = MimeTypeMap.getSingleton()
        val stack = ArrayDeque<Pair<File, Int>>()
        for (r in roots) stack.add(File(r) to 0)
        var budget = 60_000
        while (stack.isNotEmpty() && out.size < 5_000) {
            val (dir, depth) = stack.removeLast()
            if (depth > MAX_FS_DEPTH) continue
            val children = runCatching { dir.listFiles() }.getOrNull() ?: continue
            for (c in children) {
                if (--budget <= 0) return out
                if (c.isDirectory) {
                    val n = c.name
                    if (n.startsWith(".") ||
                        (depth == 0 && n == "Android") ||
                        n == "data" && dir.name == "Android" ||
                        n == "obb" && dir.name == "Android"
                    ) continue
                    stack.add(c to depth + 1)
                } else {
                    val ext = c.name.substringAfterLast('.', "").lowercase()
                    if (ext !in exts) continue
                    if (c.length() <= 0L) continue
                    if (excludeMedia) {
                        val mime = mimeMap.getMimeTypeFromExtension(ext)
                        if (mime != null &&
                            (mime.startsWith("image/") || mime.startsWith("video/") || mime.startsWith("audio/"))
                        ) continue
                    }
                    out.add(c)
                }
            }
        }
        return out
    }

    private fun cursorToMaps(c: Cursor): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>(c.count)
        val idIdx    = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
        val nameIdx  = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
        val sizeIdx  = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
        val dateIdx  = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
        val mimeIdx  = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
        val mediaIdx = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
        val dataIdx  = c.getColumnIndex(MediaStore.Files.FileColumns.DATA)
        val wIdx     = c.getColumnIndex("width")
        val hIdx     = c.getColumnIndex("height")
        val dIdx     = c.getColumnIndex("duration")

        while (c.moveToNext()) {
            val id        = c.getLong(idIdx)
            val mediaType = c.getInt(mediaIdx)
            val uri       = buildMediaUri(id, mediaType)

            val rawName = c.getStringOrNull(nameIdx)
            val name    = if (!rawName.isNullOrBlank()) {
                rawName
            } else {
                val seg = uri.substringAfterLast('/')
                Uri.decode(seg).takeIf { it.isNotBlank() } ?: ""
            }

            out.add(
                mapOf(
                    "id"           to id,
                    "uri"          to uri,
                    "name"         to name,
                    "size"         to c.getLong(sizeIdx),
                    "dateModified" to c.getLong(dateIdx) * 1000L,
                    "mimeType"     to c.getStringOrNull(mimeIdx),
                    "mediaType"    to mediaType,
                    "path"         to (if (dataIdx >= 0) c.getStringOrNull(dataIdx) else null),
                    "width"        to if (wIdx >= 0) c.getInt(wIdx)  else 0,
                    "height"       to if (hIdx >= 0) c.getInt(hIdx)  else 0,
                    "duration"     to if (dIdx >= 0) c.getLong(dIdx) else 0L
                )
            )
        }
        return out
    }

    private fun Cursor.getStringOrNull(i: Int): String? =
        if (isNull(i)) null else getString(i)

    private fun buildMediaUri(id: Long, mediaType: Int): String {
        val base = when (mediaType) {
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
        return Uri.withAppendedPath(base, id.toString()).toString()
    }

    // ─── Constants ───────────────────────────────────────────────────────

    companion object {

        /** Maximum directory depth for the file-system fallback scan. */
        private const val MAX_FS_DEPTH = 5

        /**
         * MIME whitelist for [Type.DOCUMENT] when no caller extensions are given.
         * Deliberately omits image, video and audio MIME types so screenshots
         * and media files never bleed into the Documents tab.
         */
        private val DOCUMENT_MIMES: List<String> = listOf(
            "application/pdf",
            "application/msword",
            "application/vnd.ms-excel",
            "application/vnd.ms-powerpoint",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.template",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.template",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "application/vnd.openxmlformats-officedocument.presentationml.slideshow",
            "application/vnd.openxmlformats-officedocument.presentationml.template",
            "application/vnd.oasis.opendocument.text",
            "application/vnd.oasis.opendocument.spreadsheet",
            "application/vnd.oasis.opendocument.presentation",
            "text/plain",
            "text/html",
            "text/csv",
            "text/xml",
            "application/xml",
            "application/json",
            "application/rtf",
            "text/rtf",
            "text/markdown",
            "application/epub+zip",
            "application/x-mobipocket-ebook",
            "application/x-fictionbook+xml",
            "application/zip",
            "application/x-zip-compressed",
            "application/x-rar-compressed",
            "application/vnd.rar",
            "application/x-7z-compressed",
            "application/x-tar",
            "application/gzip",
            "application/x-bzip2",
            "application/x-xz",
            "application/x-lzma",
            "application/x-sqlite3",
            "application/vnd.sqlite3",
            "application/vnd.android.package-archive",
            // Windows / cross-platform executables and installers
            "application/x-msdownload",
            "application/vnd.microsoft.portable-executable",
            "application/x-dosexec",
            "application/x-ms-dos-executable",
            "application/x-msi",
            "application/vnd.ms-installer",
            "application/x-msix",
            "application/x-appx",
            // Disk images
            "application/x-iso9660-image",
            "application/x-apple-diskimage",
            "application/x-vhd",
            // Misc document formats
            "text/tab-separated-values",
            "application/xhtml+xml",
            "application/vnd.ms-access",
            "application/x-msaccess"
        )

        /**
         * Extensions matched via DISPLAY_NAME LIKE when no caller extensions are
         * given, because MediaStore frequently stores NULL or a wrong MIME for
         * archives (zip, rar, 7z...) and ebook formats on many devices.
         */
        private val DOCUMENT_FALLBACK_EXTS: List<String> = listOf(
            // Archives / app packages
            "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "lzma", "zst",
            "apk", "xapk", "apks", "ipa",
            // Windows / cross-platform executables and installers
            "exe", "msi", "msix", "appx", "jar",
            "bat", "cmd", "ps1", "vbs", "sh",
            // Disk images
            "iso", "img", "dmg", "vhd", "vhdx",
            // Office documents
            "pdf", "doc", "docx", "docm", "dot", "dotx",
            "xls", "xlsx", "xlsm", "xlsb", "xlt",
            "ppt", "pptx", "pptm", "pps", "ppsx", "pot",
            "odt", "ods", "odp",
            "pages", "numbers", "key",
            // Plain text / markup / data
            "txt", "rtf", "md", "csv", "tsv", "log",
            "html", "htm", "xml", "json", "yaml", "yml", "ini", "cfg",
            // eBooks / comics
            "epub", "mobi", "azw3", "fb2", "cbz", "cbr",
            // Databases
            "db", "sqlite", "sqlite3", "mdb", "accdb"
        )

        /** All archive / package extensions scanned by [Type.ARCHIVE]. */
        val ARCHIVE_EXTS: Set<String> = setOf(
            "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz",
            "lz", "lzma", "zst", "tzst", "apk", "aab", "deb", "rpm", "jar", "war",
            "cbz", "cbr", "epub", "whl", "egg"
        )

        /**
         * Extensions that should always be matched via DISPLAY_NAME LIKE rather
         * than mime_type IN, because MimeTypeMap may map them to unexpected types
         * (e.g. "ts" → "video/mp2ts") or return null on some devices.
         */
        private val ALWAYS_LIKE_EXTS: Set<String> = setOf(
            "dart", "kt", "kts", "swift", "py", "rb", "go", "rs", "cpp", "c",
            "h", "cs", "java", "js", "ts", "sh", "bash", "zsh", "fish",
            "toml", "yaml", "yml", "ini", "cfg", "conf", "env", "properties",
            "gradle", "cmake", "makefile",
            "md", "markdown", "tex", "log", "diff", "patch",
            "db", "sqlite", "sqlite3", "mdb"
        )
    }
}
