package com.example.media_manager

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.media.ThumbnailUtils
import android.os.Environment
import android.provider.MediaStore
import android.util.LruCache
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit
import io.flutter.plugin.common.PluginRegistry

/** MediaManagerPlugin */
class MediaManagerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var activityBinding: ActivityPluginBinding? = null
  
  // Memory management improvements
  private val imageCache = LruCache<String, Bitmap>(10 * 1024 * 1024) // Reduced to 10MB
  private val executorService = Executors.newFixedThreadPool(2) // Reduced threads
  private val dispatcher = executorService.asCoroutineDispatcher()
  private var scope: CoroutineScope? = null
  
  // Track active operations to cancel them on cleanup
  private val activeJobs = mutableSetOf<Job>()

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "media_manager")
    context = flutterPluginBinding.applicationContext
    channel.setMethodCallHandler(this)
    
    // Initialize coroutine scope with proper lifecycle management
    scope = CoroutineScope(dispatcher + SupervisorJob())
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "getDirectories" -> {
        getDirectories(result)
      }
      "getDirectoryContents" -> {
        val path = call.argument<String>("path") ?: Environment.getExternalStorageDirectory().path
        getDirectoryContents(path, result)
      }
      "getImagePreview" -> {
        val imagePath = call.argument<String>("path")
        if (imagePath != null) {
          getImagePreview(imagePath, result)
        } else {
          result.error("INVALID_PATH", "Invalid image path", null)
        }
      }
      "clearImageCache" -> {
        clearImageCache()
        result.success(true)
      }
      "requestStoragePermission" -> {
        requestStoragePermission(result)
      }
      "getAllImages" -> {
        getAllFilesByType(result, listOf("jpg", "jpeg", "png", "gif", "bmp", "webp", "tiff", "svg", "ico", "heif", "avif"))
      }
      "getAllVideos" -> {
        getAllFilesByType(result, listOf("mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm"))
      }
      "getAllAudio" -> {
        getAllFilesByType(result, listOf("mp3", "wav", "m4a", "ogg", "flac", "aac", "wma", "opus"))
      }
      "getAllDocuments" -> {
        getAllFilesByType(result, listOf(
          // Common document formats first
          "pdf", "doc", "docx", "txt", "rtf",
          
          // Spreadsheet formats
          "xls", "xlsx", "xlsm", "xlsb", "xlt", "xltx", "xltm",
          "ods", "ots", "csv",

          // Presentation formats
          "ppt", "pptx", "pptm", "pps", "ppsx", "ppsm",
          "pot", "potx", "potm", "odp", "otp",

          // Programming/Code files
          "dart", "php", "js", "jsx", "ts", "tsx", "py", "java",
          "kt", "kts", "cpp", "c", "h", "hpp", "cs", "go", "rb",
          "swift", "m", "mm", "sh", "bash", "ps1", "bat", "cmd",
          "pl", "pm", "lua", "sql", "json", "yaml", "yml", "toml",
          "ini", "cfg", "conf", "gradle", "properties", "asm",
          "s", "v", "vhdl", "verilog", "r", "d", "f", "f90",
          "coffee", "scala", "groovy", "clj", "cljc", "cljs",
          "edn", "ex", "exs", "elm", "erl", "hrl", "fs", "fsx",
          "fsi", "ml", "mli", "nim", "pde", "pp", "pas", "lisp",
          "cl", "scm", "ss", "rkt", "st", "tcl", "vhd", "vhdl",

          // Web development
          "vue", "svelte", "astro", "php", "phtml", "twig",
          "mustache", "hbs", "ejs", "haml", "scss", "sass",
          "less", "styl", "stylus", "coffee", "litcoffee",
          "graphql", "gql", "wasm", "wat",

          // Other common document formats
          "md", "markdown", "tex", "log", "pages", "wpd", "wps",
          "abw", "zabw"
        ))
      }
      "getAllZipFiles" -> {
        val job = scope?.launch {
          try {
            val zipFiles = getAllZipFiles()
            withContext(Dispatchers.Main) {
              result.success(zipFiles)
            }
          } catch (e: Exception) {
            // Error getting zip files
            withContext(Dispatchers.Main) {
              result.error("SCAN_ERROR", "Failed to get zip files: ${e.message}", null)
            }
          }
        }
        job?.let { activeJobs.add(it) }
      }
      "getVideoThumbnail" -> {
        val job = scope?.launch {
          try {
            val path = call.argument<String>("path")
            if (path != null) {
              val thumbnail = getVideoThumbnail(path)
              withContext(Dispatchers.Main) {
                result.success(thumbnail)
              }
            } else {
              withContext(Dispatchers.Main) {
                result.error("INVALID_ARGUMENT", "Video path is required", null)
              }
            }
          } catch (e: Exception) {
            withContext(Dispatchers.Main) {
              result.error("THUMBNAIL_ERROR", "Failed to generate video thumbnail: ${e.message}", null)
            }
          }
        }
        job?.let { activeJobs.add(it) }
      }
      "getAudioThumbnail" -> {
        val job = scope?.launch {
          try {
            val path = call.argument<String>("path")
            if (path != null) {
              val thumbnail = getAudioThumbnail(path)
              withContext(Dispatchers.Main) {
                result.success(thumbnail)
              }
            } else {
              withContext(Dispatchers.Main) {
                result.error("INVALID_ARGUMENT", "Audio path is required", null)
              }
            }
          } catch (e: Exception) {
            withContext(Dispatchers.Main) {
              result.error("AUDIO_THUMBNAIL_ERROR", "Failed to extract album art: ${e.message}", null)
            }
          }
        }
        job?.let { activeJobs.add(it) }
      }
      "getAllFilesByFormat" -> {
        val formats = call.argument<List<String>>("formats")
        if (formats != null && formats.isNotEmpty()) {
          android.util.Log.d("MediaManager", "Getting files by formats: ${formats.joinToString(", ")}")
          android.util.Log.d("MediaManager", "Total formats requested: ${formats.size}")
          getAllFilesByType(result, formats)
        } else {
          android.util.Log.w("MediaManager", "No formats provided or empty list")
          result.success(emptyList<String>())
        }
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun getDirectories(result: Result) {
    val job = scope?.launch {
      try {
        android.util.Log.d("MediaManager", "Starting getDirectories...")
        android.util.Log.d("MediaManager", "Android SDK: ${android.os.Build.VERSION.SDK_INT}")
        
        val directories = mutableListOf<Map<String, Any>>()
        
        android.util.Log.d("MediaManager", "Creating comprehensive directory list...")
        
        try {
          // Add all standard directories
          val standardDirs = listOf(
            Environment.DIRECTORY_DCIM to "DCIM",
            Environment.DIRECTORY_PICTURES to "Pictures", 
            Environment.DIRECTORY_MOVIES to "Movies",
            Environment.DIRECTORY_MUSIC to "Music",
            Environment.DIRECTORY_DOWNLOADS to "Downloads",
            Environment.DIRECTORY_DOCUMENTS to "Documents",
            Environment.DIRECTORY_PODCASTS to "Podcasts",
            Environment.DIRECTORY_RINGTONES to "Ringtones",
            Environment.DIRECTORY_ALARMS to "Alarms",
            Environment.DIRECTORY_NOTIFICATIONS to "Notifications"
          )
          
          standardDirs.forEach { (dirType, displayName) ->
            try {
              val dir = Environment.getExternalStoragePublicDirectory(dirType)
              if (dir != null && dir.exists()) {
                android.util.Log.d("MediaManager", "Adding $displayName directory: ${dir.absolutePath}")
                directories.add(mapOf(
                  "name" to displayName,
                  "path" to dir.absolutePath
                ))
              }
            } catch (e: Exception) {
              // Error accessing directory
            }
          }
          
          // Add root storage directory for browsing
          val rootStorage = File("/storage/emulated/0")
          if (rootStorage.exists() && rootStorage.isDirectory) {
            // Adding root storage directory
            directories.add(mapOf(
              "name" to "Internal Storage",
              "path" to rootStorage.absolutePath
            ))
          }
          
          // Try to add other common directories
          val commonDirs = listOf(
            "/storage/emulated/0/Android" to "Android",
            "/storage/emulated/0/WhatsApp" to "WhatsApp",
            "/storage/emulated/0/Telegram" to "Telegram",
            "/storage/emulated/0/Camera" to "Camera"
          )
          
          commonDirs.forEach { (path, name) ->
            try {
              val dir = File(path)
              if (dir.exists() && dir.isDirectory) {
                // Adding directory
                directories.add(mapOf(
                  "name" to name,
                  "path" to path
                ))
              }
            } catch (e: Exception) {
              // Error accessing directory
            }
          }
          
        } catch (e: Exception) {
          // Error creating directory list
          // Add fallback directories
          directories.add(mapOf(
            "name" to "Internal Storage",
            "path" to "/storage/emulated/0"
          ))
          directories.add(mapOf(
            "name" to "Downloads",
            "path" to "/storage/emulated/0/Download"
          ))
        }

        withContext(Dispatchers.Main) {
          result.success(directories)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          result.error("DIRECTORY_ACCESS_ERROR", "Error accessing directories: ${e.message}", null)
        }
      }
    }
    job?.let { activeJobs.add(it) }
  }

  private fun getDirectoryContents(directoryPath: String, result: Result) {
    val job = scope?.launch {
      try {
        val directory = File(directoryPath)
        if (!directory.exists() || !directory.isDirectory) {
          withContext(Dispatchers.Main) {
            result.error("INVALID_DIRECTORY", "Invalid directory path: $directoryPath", null)
          }
          return@launch
        }

        val contents = mutableListOf<Map<String, Any>>()
        directory.listFiles()?.forEach { file ->
          val fileInfo = mutableMapOf<String, Any>()
          fileInfo["name"] = file.name
          fileInfo["path"] = file.absolutePath
          fileInfo["isDirectory"] = file.isDirectory
          fileInfo["size"] = file.length()
          fileInfo["lastModified"] = file.lastModified()

          // Add file type and additional metadata
          if (!file.isDirectory) {
            val extension = file.extension.lowercase()
            fileInfo["type"] = when {
              listOf("jpg", "jpeg", "png", "gif", "bmp", "webp").contains(extension) -> "image"
              listOf("mp4", "avi", "mov", "mkv", "wmv", "flv").contains(extension) -> "video"
              listOf("mp3", "wav", "ogg", "m4a", "flac").contains(extension) -> "audio"
              listOf("pdf", "doc", "docx", "txt", "rtf").contains(extension) -> "document"
              listOf("zip", "rar", "7z").contains(extension) -> "zip"
              else -> "other"
            }

            // Add file extension
            fileInfo["extension"] = extension

            // Add readable file size
            fileInfo["readableSize"] = formatFileSize(file.length())
          } else {
            fileInfo["type"] = "directory"
            fileInfo["extension"] = ""
            fileInfo["readableSize"] = ""
          }

          contents.add(fileInfo)
        }

        // Sort contents: directories first, then files alphabetically
        contents.sortWith(compareBy(
          { (it["isDirectory"] as Boolean).not() },
          { it["name"] as String }
        ))

        // Convert to a format that Flutter can handle
        val flutterContents = contents.map { item ->
          mapOf(
            "name" to (item["name"] as String),
            "path" to (item["path"] as String),
            "isDirectory" to (item["isDirectory"] as Boolean),
            "type" to (item["type"] as String),
            "extension" to (item["extension"] as String),
            "readableSize" to (item["readableSize"] as String)
          )
        }

        withContext(Dispatchers.Main) {
          result.success(flutterContents)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          result.error("FILE_ACCESS_ERROR", "Error accessing files: ${e.message}", null)
        }
      }
    }
    job?.let { activeJobs.add(it) }
  }

  private fun getImagePreview(imagePath: String, result: Result) {
    val job = scope?.launch {
      try {
        // Check cache
        val cachedBitmap = imageCache.get(imagePath)
        if (cachedBitmap != null) {
          val byteArray = compressBitmapToByteArray(cachedBitmap)
          withContext(Dispatchers.Main) {
            result.success(byteArray)
          }
          return@launch
        }

        // Load and cache image
        val file = File(imagePath)
        if (!file.exists() || !file.isFile) {
          withContext(Dispatchers.Main) {
            result.error("INVALID_IMAGE", "Invalid image", null)
          }
          return@launch
        }

        // Calculate optimal sample size based on target dimensions
        val options = BitmapFactory.Options().apply {
          inJustDecodeBounds = true
          BitmapFactory.decodeFile(imagePath, this)
          val targetWidth = 800  // Increased from previous value
          val targetHeight = 800  // Increased from previous value
          val scaleFactor = minOf(
            outWidth / targetWidth,
            outHeight / targetHeight
          ).coerceAtLeast(1)
          inSampleSize = scaleFactor
          inJustDecodeBounds = false
        }

        val bitmap = BitmapFactory.decodeFile(imagePath, options)
        if (bitmap != null) {
          // Save to cache
          imageCache.put(imagePath, bitmap)
          val byteArray = compressBitmapToByteArray(bitmap)
          withContext(Dispatchers.Main) {
            result.success(byteArray)
          }
        } else {
          withContext(Dispatchers.Main) {
            result.error("IMAGE_DECODE_ERROR", "Error decoding image", null)
          }
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          result.error("IMAGE_PREVIEW_ERROR", "Error generating preview: ${e.message}", null)
        }
      }
    }
    job?.let { activeJobs.add(it) }
  }

  private fun compressBitmapToByteArray(bitmap: Bitmap): ByteArray {
    return bitmap.let {
      val outputStream = java.io.ByteArrayOutputStream()
      // Increased quality from 80 to 90
      it.compress(Bitmap.CompressFormat.JPEG, 90, outputStream)
      outputStream.toByteArray()
    }
  }

  private fun clearImageCache() {
    imageCache.evictAll()
  }

  private fun requestStoragePermission(result: Result) {
    // Requesting storage permissions
    
    val permissions = when {
      android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU -> {
        // Android 13+ (API 33+) - Granular media permissions
        // Using Android 13+ granular permissions
        arrayOf(
          Manifest.permission.READ_MEDIA_IMAGES,
          Manifest.permission.READ_MEDIA_VIDEO,
          Manifest.permission.READ_MEDIA_AUDIO
        )
      }
      android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R -> {
        // Android 11+ (API 30+) - Scoped storage with MANAGE_EXTERNAL_STORAGE
        // Using Android 11+ permissions with scoped storage
        arrayOf(
          Manifest.permission.READ_EXTERNAL_STORAGE,
          Manifest.permission.MANAGE_EXTERNAL_STORAGE
        )
      }
      else -> {
        // Android 10 and below - Legacy storage permission
        // Using legacy READ_EXTERNAL_STORAGE permission
        arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
      }
    }

    // Checking permissions
    
    val permissionStatus = permissions.map { permission ->
      val status = ContextCompat.checkSelfPermission(context, permission)
      android.util.Log.d("MediaManager", "Permission $permission: ${if (status == PackageManager.PERMISSION_GRANTED) "GRANTED" else "DENIED"}")
      status
    }
    
    val hasAllPermissions = permissionStatus.all { it == PackageManager.PERMISSION_GRANTED }
    android.util.Log.d("MediaManager", "All permissions granted: $hasAllPermissions")

    if (hasAllPermissions) {
      android.util.Log.d("MediaManager", "All permissions already granted")
      result.success(true)
    } else {
      android.util.Log.d("MediaManager", "Requesting permissions from user...")
      activityBinding?.let { binding ->
        val listener = object : PluginRegistry.RequestPermissionsResultListener {
          override fun onRequestPermissionsResult(
            requestCode: Int,
            permissions: Array<String>,
            grantResults: IntArray
          ): Boolean {
            if (requestCode == 1) {
              android.util.Log.d("MediaManager", "Permission result received")
              grantResults.forEachIndexed { index, result ->
                android.util.Log.d("MediaManager", "Permission ${permissions[index]}: ${if (result == PackageManager.PERMISSION_GRANTED) "GRANTED" else "DENIED"}")
              }
              
              val granted = grantResults.isNotEmpty() && 
                          grantResults.all { it == PackageManager.PERMISSION_GRANTED }
              android.util.Log.d("MediaManager", "Final permission result: $granted")
              result.success(granted)
              binding.removeRequestPermissionsResultListener(this)
              return true
            }
            return false
          }
        }
        
        binding.addRequestPermissionsResultListener(listener)
        ActivityCompat.requestPermissions(
          binding.activity,
          permissions,
          1
        )
      } ?: run {
        // Activity not available for permission request
        result.error("ACTIVITY_NOT_AVAILABLE", "Activity is not available for permission request", null)
      }
    }
  }

  private fun buildSelectionForExtensions(extensions: List<String>): String {
    if (extensions.isEmpty()) return ""
    
    val conditions = extensions.map { ext ->
      "${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE '%.${ext}'"
    }
    return conditions.joinToString(" OR ")
  }

  private fun getAllFilesByType(result: Result, extensions: List<String>) {
    val job = scope?.launch {
      try {
        android.util.Log.d("MediaManager", "getAllFilesByType called with extensions: ${extensions.joinToString(", ")}")
        if (extensions.isEmpty()) {
          android.util.Log.w("MediaManager", "No extensions provided, returning empty list")
          withContext(Dispatchers.Main) {
            result.success(emptyList<String>())
          }
          return@launch
        }
        
        val files = mutableListOf<String>()
        
        // Use IO dispatcher for file operations
        withContext(Dispatchers.IO) {
          // Check if these are document/code file extensions that need directory scanning
          val documentExtensions = listOf(
            "pdf", "doc", "docx", "txt", "rtf", "xls", "xlsx", "xlsm", "xlsb", "xlt", "xltx", "xltm",
            "ods", "ots", "csv", "ppt", "pptx", "pptm", "pps", "ppsx", "ppsm", "pot", "potx", "potm",
            "odp", "otp", "dart", "php", "js", "jsx", "ts", "tsx", "py", "java", "kt", "kts", "cpp",
            "c", "h", "hpp", "cs", "go", "rb", "swift", "m", "mm", "sh", "bash", "ps1", "bat", "cmd",
            "pl", "pm", "lua", "sql", "json", "yaml", "yml", "toml", "ini", "cfg", "conf", "gradle",
            "properties", "asm", "s", "v", "vhdl", "verilog", "r", "d", "f", "f90", "coffee", "scala",
            "groovy", "clj", "cljc", "cljs", "edn", "ex", "exs", "elm", "erl", "hrl", "fs", "fsx",
            "fsi", "ml", "mli", "nim", "pde", "pp", "pas", "lisp", "cl", "scm", "ss", "rkt", "st",
            "tcl", "vhd", "vue", "svelte", "astro", "phtml", "twig", "mustache", "hbs", "ejs",
            "haml", "scss", "sass", "less", "styl", "stylus", "litcoffee", "graphql", "gql",
            "wasm", "wat", "md", "markdown", "tex", "log", "pages", "wpd", "wps", "abw", "zabw"
          )
          
          val hasDocumentExtensions = extensions.any { it in documentExtensions }
          
          if (hasDocumentExtensions) {
            // Document extensions detected, using directory scanning
            // Use directory scanning for document files
            scanDirectoriesForFiles(files, extensions)
          } else {
            // Media extensions detected, using MediaStore
            // Use MediaStore for media files (images, videos, audio)
            scanMediaStoreForFiles(files, extensions)
          }
        }

        // Files scan completed

        withContext(Dispatchers.Main) {
          result.success(files)
        }
      } catch (e: Exception) {
        // Error in getAllFilesByType
        withContext(Dispatchers.Main) {
          result.error("FILE_SCAN_ERROR", "Error scanning files: ${e.message}", null)
        }
      }
    }
    job?.let { activeJobs.add(it) }
  }
  
  private suspend fun scanMediaStoreForFiles(files: MutableList<String>, extensions: List<String>) {
    try {
      val projection = arrayOf(
        MediaStore.Files.FileColumns.DATA,
        MediaStore.Files.FileColumns.DISPLAY_NAME
      )
      val selection = buildSelectionForExtensions(extensions)
      
      // MediaStore selection query
      
      if (selection.isEmpty()) {
        // Empty selection query, returning
        return
      }
      
      val cursor = context.contentResolver.query(
        MediaStore.Files.getContentUri("external"),
        projection,
        selection,
        null,
        "${MediaStore.Files.FileColumns.DISPLAY_NAME} ASC"
      )
      
      cursor?.use {
        // MediaStore cursor results
        val dataColumn = it.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
        
        var processedCount = 0
        while (it.moveToNext()) {
          val filePath = it.getString(dataColumn)
          if (filePath != null && File(filePath).exists()) {
            files.add(filePath)
            // Added file
          }
          
          // Yield control every 50 files to prevent ANR
          processedCount++
          if (processedCount % 50 == 0) {
            yield()
          }
        }
      } ?: run {
        android.util.Log.w("MediaManager", "MediaStore query returned null cursor")
      }
    } catch (e: Exception) {
      // MediaStore query failed
    }
  }
  
  private suspend fun scanDirectoriesForFiles(files: MutableList<String>, extensions: List<String>) {
    // Starting directory scan for document files
    
    // Common directories to scan for documents
    val commonDirs = listOf(
      Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
      Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS),
      File(Environment.getExternalStorageDirectory(), "Download"),
      File(Environment.getExternalStorageDirectory(), "Documents"),
      File(Environment.getExternalStorageDirectory(), "WhatsApp/Media/WhatsApp Documents"),
      File(Environment.getExternalStorageDirectory(), "Telegram"),
      File(Environment.getExternalStorageDirectory(), "AndroidIDEProjects"),
      File(Environment.getExternalStorageDirectory(), "Android/data"),
      Environment.getExternalStorageDirectory() // Root directory
    )
    
    suspend fun scanDirectory(directory: File, maxDepth: Int = 3, currentDepth: Int = 0) {
      if (currentDepth >= maxDepth) return
      
      try {
        // Scanning directory
        val fileList = directory.listFiles()
        
        fileList?.forEach { file ->
          // Yield control to avoid blocking
          yield()
          
          if (file.isDirectory && currentDepth < maxDepth - 1) {
            // Skip system directories to avoid scanning too much
            if (!file.name.startsWith(".") && 
                !file.name.equals("Android", ignoreCase = true) ||
                file.absolutePath.contains("Documents") ||
                file.absolutePath.contains("Download")) {
              scanDirectory(file, maxDepth, currentDepth + 1)
            }
          } else if (file.isFile) {
            val extension = file.extension.lowercase()
            if (extensions.contains(extension)) {
              if (!files.contains(file.absolutePath)) { // Avoid duplicates
                files.add(file.absolutePath)
                // Found document file
              }
            }
          }
        }
      } catch (e: SecurityException) {
        // Cannot access directory
      } catch (e: Exception) {
        // Error scanning directory
      }
    }
    
    commonDirs.forEach { dir ->
      if (dir != null && dir.exists() && dir.canRead()) {
        // Scanning common directory
        scanDirectory(dir)
      } else {
        // Cannot access directory
      }
    }
    
    // Directory scan completed
  }

  private suspend fun getAllZipFiles(): List<String> = withContext(Dispatchers.IO) {
    val zipFiles = mutableListOf<String>()
    
    android.util.Log.d("MediaManager", "Starting zip file scan on Android SDK: ${android.os.Build.VERSION.SDK_INT}")
    
    // Check permissions first - enhanced for newer Android versions
    val hasPermission = when {
      android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU -> {
        // Android 13+ permissions
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_MEDIA_IMAGES) == PackageManager.PERMISSION_GRANTED
      }
      else -> {
        // Legacy permission
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
      }
    }
    
    if (!hasPermission) {
      android.util.Log.w("MediaManager", "Storage permission not granted, cannot scan for zip files")
      return@withContext zipFiles
    }
    
    // First, try MediaStore approach for all versions
    try {
      android.util.Log.d("MediaManager", "Trying MediaStore for zip files...")
      val projection = arrayOf(
        MediaStore.Files.FileColumns.DATA,
        MediaStore.Files.FileColumns.DISPLAY_NAME,
        MediaStore.Files.FileColumns.SIZE
      )
      
      val selection = "${MediaStore.Files.FileColumns.DATA} LIKE '%.zip' OR " +
                     "${MediaStore.Files.FileColumns.DATA} LIKE '%.ZIP' OR " +
                     "${MediaStore.Files.FileColumns.DATA} LIKE '%.rar' OR " +
                     "${MediaStore.Files.FileColumns.DATA} LIKE '%.RAR' OR " +
                     "${MediaStore.Files.FileColumns.DATA} LIKE '%.7z' OR " +
                     "${MediaStore.Files.FileColumns.DATA} LIKE '%.7Z'"
      
      val cursor = context.contentResolver.query(
        MediaStore.Files.getContentUri("external"),
        projection,
        selection,
        null,
        "${MediaStore.Files.FileColumns.DISPLAY_NAME} ASC"
      )
      
      cursor?.use {
        android.util.Log.d("MediaManager", "MediaStore zip cursor count: ${it.count}")
        val dataColumn = it.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
        
        while (it.moveToNext()) {
          val filePath = it.getString(dataColumn)
          if (filePath != null && File(filePath).exists()) {
            zipFiles.add(filePath)
            android.util.Log.i("MediaManager", "MediaStore found zip: $filePath")
          }
        }
      }
    } catch (e: Exception) {
      android.util.Log.w("MediaManager", "MediaStore zip query failed: ${e.message}")
    }
    
    // If MediaStore didn't find files or for comprehensive search, also scan directories
    android.util.Log.d("MediaManager", "MediaStore found ${zipFiles.size} zip files, now scanning directories...")
    // Scan common directories for comprehensive coverage
    val commonDirs = listOf(
      Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
      Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS),
      File(Environment.getExternalStorageDirectory(), "Download"),
      File(Environment.getExternalStorageDirectory(), "Documents"),
      File(Environment.getExternalStorageDirectory(), "WhatsApp/Media/WhatsApp Documents"),
      File(Environment.getExternalStorageDirectory(), "Telegram"),
      Environment.getExternalStorageDirectory() // Root directory for older Android
    )
    
    suspend fun scanDirectoryForZipFiles(directory: File, maxDepth: Int = 2, currentDepth: Int = 0) {
      if (currentDepth >= maxDepth) return
      
      try {
        android.util.Log.d("MediaManager", "Scanning directory (depth $currentDepth): ${directory.absolutePath}")
        val fileList = directory.listFiles()
        android.util.Log.d("MediaManager", "Found ${fileList?.size ?: 0} items in ${directory.name}")
        
        fileList?.forEach { file ->
          // Yield control to avoid blocking
          yield()
          
          if (file.isDirectory && currentDepth < maxDepth - 1) {
            android.util.Log.v("MediaManager", "Entering subdirectory: ${file.name}")
            scanDirectoryForZipFiles(file, maxDepth, currentDepth + 1)
          } else if (file.isFile) {
            val extension = file.extension.lowercase()
            if (listOf("zip", "rar", "7z").contains(extension)) {
              if (!zipFiles.contains(file.absolutePath)) { // Avoid duplicates
                zipFiles.add(file.absolutePath)
                android.util.Log.i("MediaManager", "Found zip file: ${file.name} (${file.absolutePath})")
              }
            }
          }
        }
      } catch (e: SecurityException) {
        android.util.Log.w("MediaManager", "Cannot access directory: ${directory.absolutePath} - ${e.message}")
      } catch (e: Exception) {
        android.util.Log.e("MediaManager", "Error scanning directory: ${directory.absolutePath}", e)
      }
    }
    
    commonDirs.forEach { dir ->
      if (dir != null && dir.exists() && dir.canRead()) {
        android.util.Log.d("MediaManager", "Scanning common directory: ${dir.absolutePath}")
        scanDirectoryForZipFiles(dir)
      } else {
        android.util.Log.w("MediaManager", "Cannot access directory: ${dir?.absolutePath ?: "null"}")
      }
    }
    
    android.util.Log.d("MediaManager", "Total zip files found: ${zipFiles.size}")
    zipFiles.take(3).forEach { path ->
      android.util.Log.d("MediaManager", "Sample zip: $path")
    }
    return@withContext zipFiles
  }

  private suspend fun getVideoThumbnail(path: String): ByteArray? = withContext(Dispatchers.IO) {
    try {
      val bitmap = ThumbnailUtils.createVideoThumbnail(path, MediaStore.Video.Thumbnails.MINI_KIND)
      bitmap?.let { compressBitmapToByteArray(it) }
    } catch (e: Exception) {
      android.util.Log.w("MediaManager", "Failed to create video thumbnail for $path: ${e.message}")
      null
    }
  }

  private suspend fun getAudioThumbnail(path: String): ByteArray? = withContext(Dispatchers.IO) {
    var retriever: MediaMetadataRetriever? = null
    return@withContext try {
      retriever = MediaMetadataRetriever()
      retriever.setDataSource(path)
      val albumArt = retriever.embeddedPicture
      albumArt
    } catch (e: Exception) {
      android.util.Log.w("MediaManager", "Failed to extract album art from $path: ${e.message}")
      null
    } finally {
      try {
        retriever?.release()
      } catch (e: Exception) {
        android.util.Log.w("MediaManager", "Failed to release MediaMetadataRetriever: ${e.message}")
      }
    }
  }


  private fun formatFileSize(size: Long): String {
    val units = arrayOf("B", "KB", "MB", "GB", "TB")
    var fileSize = size.toDouble()
    var unitIndex = 0

    while (fileSize >= 1024 && unitIndex < units.size - 1) {
      fileSize /= 1024
      unitIndex++
    }

    return "%.2f %s".format(fileSize, units[unitIndex])
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    
    // Cancel all active jobs to prevent memory leaks
    activeJobs.forEach { job ->
      if (job.isActive) {
        job.cancel()
      }
    }
    activeJobs.clear()
    
    // Clean up resources
    scope?.cancel()
    scope = null
    clearImageCache()
    
    // Clean up executor service
    try {
      executorService.shutdown()
      if (!executorService.awaitTermination(2, java.util.concurrent.TimeUnit.SECONDS)) {
        executorService.shutdownNow()
      }
    } catch (e: InterruptedException) {
      executorService.shutdownNow()
      Thread.currentThread().interrupt()
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activityBinding = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activityBinding = binding
  }

  override fun onDetachedFromActivity() {
    activityBinding = null
  }
}
