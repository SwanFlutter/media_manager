package com.example.media_manager

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
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
import io.flutter.plugin.common.PluginRegistry

/** MediaManagerPlugin */
class MediaManagerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var activityBinding: ActivityPluginBinding? = null
  private val imageCache = LruCache<String, Bitmap>(20 * 1024 * 1024) // 20MB cache
  private val videoThumbnailCache = LruCache<String, Bitmap>(20 * 1024 * 1024) // 20MB cache for video thumbnails
  private val dispatcher = Executors.newFixedThreadPool(4).asCoroutineDispatcher()
  private val scope = CoroutineScope(dispatcher)

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "media_manager")
    context = flutterPluginBinding.applicationContext
    channel.setMethodCallHandler(this)
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
      "getVideoThumbnail" -> {
        val videoPath = call.argument<String>("path")
        if (videoPath != null) {
          getVideoThumbnail(videoPath, result)
        } else {
          result.error("INVALID_PATH", "Invalid video path", null)
        }
      }
      "clearImageCache" -> {
        clearImageCache()
        result.success(true)
      }
      "clearVideoThumbnailCache" -> {
        clearVideoThumbnailCache()
        result.success(true)
      }
      "clearAllCaches" -> {
        clearImageCache()
        clearVideoThumbnailCache()
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
        getAllAudioFilesWithCover(result, listOf("mp3", "wav", "m4a", "ogg", "flac", "aac", "wma", "opus"))
      }
      "getAllDocuments" -> {
        getAllFilesByType(result, listOf(// Spreadsheet formats
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

          // CAD/Design files
          "dwg", "dxf", "dgn", "stl", "obj", "3ds", "max", "blend",
          "skp", "ai", "psd", "eps", "svg", "fig", "xd", "indd",
          "cdr", "afdesign", "afphoto", "afpub", "sketch", "ase",
          "aseprite", "clip", "csp", "kra", "pdn", "procreate",
          "xcf", "pd", "ps", "psb",

          // Archive formats
          "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "lz",
          "lzma", "lzh", "arj", "cab", "iso", "img", "dmg",
          "pkg", "deb", "rpm", "msi", "crx",

          // Ebook formats
          "djvu", "chm", "oxps", "xps", "cbr", "cbz", "cb7",
          "cbt", "cba", "ibooks",

          // Database files
          "db", "sqlite", "sqlite3", "mdb", "accdb", "frm", "myd",
          "myi", "ibd", "mdf", "ldf", "sdf", "nsf", "kdbx",
          "gdb", "fp7", "neo", "db3",

          // Other common document formats
          "md", "markdown", "tex", "log", "pages", "wpd", "wps",
          "abw", "zabw", "123", "602", "wk1", "wk3", "wk4", "wq1",
          "wq2", "xlw", "pmd", "sxw", "stw", "vor", "sxg", "otg",
          "odg", "odc", "odf", "odi", "oxt", "sxc", "stc", "sxd",
          "std", "sxi", "sti", "sxm", "mml", "smf", "odfl", "hwp",
          "hwt", "cell", "numbers", "key", "numbers-tef", "key-tef",
          "papers", "uof", "uot", "uos", "uop", "wmf", "emf", "cgm",
          "vsd", "vsdx", "vss", "vst", "vdx", "vsdm", "vssm", "vstm",
          "pub", "xpub", "sldprt", "sldasm", "slddrw", "prt", "asm",
          "drw", "f3d", "f3z", "iam", "ipt", "catproduct", "catpart",
          "catdrawing", "cgr", "dlv", "exp", "model", "par", "psm",
          "pwd", "session", "sim", "sldlfp", "sldlfp", "std", "stl",
          "stp", "unv", "xas", "xpr", "3dm", "3mf", "amf", "dae",
          "fbx", "glb", "gltf", "iges", "igs", "jt", "obj", "ply",
          "stp", "step", "vrml", "wrl", "x3d", "x3db", "x3dv", "xgl",
          "zgl", "bim", "ifc", "dwf", "dwfx", "nwd", "nwf", "nwc",
          "pln", "pla", "pod", "skb", "layout", "template", "lcd",
          "max", "ma", "mb", "hip", "hiplc", "hda", "hdanc", "usd",
          "usda", "usdc", "usdz", "abc", "vdb", "bgeo", "geo", "pc",
          "pdc", "pdb", "ptc", "rib", "rs", "sc", "scn", "v", "veg",
          "vfb", "vfz", "vob", "vpe", "vray", "vrmesh", "vscene",
          "vue", "w3d", "wings", "wrl", "x", "x3d", "x3dv", "xsi",
          "zbrush"))
      }
      "getAllZipFiles" -> {
        getAllFilesByType(result, listOf("zip", "rar", "7z", "tar", "gz", "bz2", "xz"))
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun getDirectories(result: Result) {
    scope.launch {
      try {
        val directories = mutableListOf<Map<String, Any>>()
        val externalStorage = Environment.getExternalStorageDirectory()

        externalStorage.listFiles()?.forEach { file ->
          if (file.isDirectory) {
            val dirInfo = mutableMapOf<String, Any>()
            dirInfo["name"] = file.name
            dirInfo["path"] = file.absolutePath
            directories.add(dirInfo)
          }
        }

        // Sort directories alphabetically
        directories.sortWith(compareBy { it["name"] as String })

        // Convert to a format that Flutter can handle
        val flutterDirectories = directories.map { dir ->
          mapOf(
            "name" to (dir["name"] as String),
            "path" to (dir["path"] as String)
          )
        }

        withContext(Dispatchers.Main) {
          result.success(flutterDirectories)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          result.error("DIRECTORY_ACCESS_ERROR", "Error accessing directories: ${e.message}", null)
        }
      }
    }
  }

  private fun getDirectoryContents(directoryPath: String, result: Result) {
    scope.launch {
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
  }

  private fun getImagePreview(imagePath: String, result: Result) {
    scope.launch {
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
  }

  private fun getVideoThumbnail(videoPath: String, result: Result) {
    scope.launch {
      try {
        // Check cache first
        val cachedThumbnail = videoThumbnailCache.get(videoPath)
        if (cachedThumbnail != null) {
          val byteArray = compressBitmapToByteArray(cachedThumbnail)
          withContext(Dispatchers.Main) {
            result.success(byteArray)
          }
          return@launch
        }

        // Verify file exists
        val file = File(videoPath)
        if (!file.exists() || !file.isFile) {
          withContext(Dispatchers.Main) {
            result.error("INVALID_VIDEO", "Invalid video file", null)
          }
          return@launch
        }

        // Generate thumbnail
        val thumbnail = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
          // For Android 10 and above
          try {
            ThumbnailUtils.createVideoThumbnail(
              file,
              android.util.Size(800, 800),
              null
            )
          } catch (e: Exception) {
            // Fallback to legacy method
            @Suppress("DEPRECATION")
            ThumbnailUtils.createVideoThumbnail(videoPath, MediaStore.Images.Thumbnails.MINI_KIND)
          }
        } else {
          // For older Android versions
          @Suppress("DEPRECATION")
          ThumbnailUtils.createVideoThumbnail(videoPath, MediaStore.Images.Thumbnails.MINI_KIND)
        }

        if (thumbnail != null) {
          // Resize thumbnail if needed
          val resizedThumbnail = if (thumbnail.width > 800 || thumbnail.height > 800) {
            val scaleFactor = minOf(800f / thumbnail.width, 800f / thumbnail.height)
            val newWidth = (thumbnail.width * scaleFactor).toInt()
            val newHeight = (thumbnail.height * scaleFactor).toInt()
            Bitmap.createScaledBitmap(thumbnail, newWidth, newHeight, true)
          } else {
            thumbnail
          }

          // Cache the thumbnail
          videoThumbnailCache.put(videoPath, resizedThumbnail)

          val byteArray = compressBitmapToByteArray(resizedThumbnail)
          withContext(Dispatchers.Main) {
            result.success(byteArray)
          }
        } else {
          withContext(Dispatchers.Main) {
            result.error("THUMBNAIL_GENERATION_ERROR", "Could not generate video thumbnail", null)
          }
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          result.error("VIDEO_THUMBNAIL_ERROR", "Error generating video thumbnail: ${e.message}", null)
        }
      }
    }
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

  private fun clearVideoThumbnailCache() {
    videoThumbnailCache.evictAll()
  }

  private fun requestStoragePermission(result: Result) {
    val permissions = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
      arrayOf(
        Manifest.permission.READ_MEDIA_IMAGES,
        Manifest.permission.READ_MEDIA_VIDEO,
        Manifest.permission.READ_MEDIA_AUDIO
      )
    } else {
      arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    }

    val hasAllPermissions = permissions.all {
      ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
    }

    if (hasAllPermissions) {
      result.success(true)
    } else {
      activityBinding?.let { binding ->
        val listener = object : PluginRegistry.RequestPermissionsResultListener {
          override fun onRequestPermissionsResult(
            requestCode: Int,
            permissions: Array<String>,
            grantResults: IntArray
          ): Boolean {
            if (requestCode == 1) {
              val granted = grantResults.isNotEmpty() &&
                      grantResults.all { it == PackageManager.PERMISSION_GRANTED }
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
        result.error("ACTIVITY_NOT_AVAILABLE", "Activity is not available for permission request", null)
      }
    }
  }

  private fun getAllFilesByType(result: Result, extensions: List<String>) {
    scope.launch {
      try {
        val files = mutableListOf<String>()

        fun scanDirectoryForFiles(directory: File) {
          directory.listFiles()?.forEach { file ->
            if (file.isDirectory) {
              scanDirectoryForFiles(file)
            } else if (extensions.contains(file.extension.lowercase())) {
              files.add(file.absolutePath)
            }
          }
        }

        val externalStorage = Environment.getExternalStorageDirectory()
        scanDirectoryForFiles(externalStorage)

        withContext(Dispatchers.Main) {
          result.success(files)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          result.error("FILE_SCAN_ERROR", "Error scanning files: ${e.message}", null)
        }
      }
    }
  }

  private fun getAllAudioFilesWithCover(result: Result, extensions: List<String>) {
    scope.launch {
      try {
        val files = mutableListOf<Map<String, Any?>>()
        fun scanDirectoryForFiles(directory: File) {
          directory.listFiles()?.forEach { file ->
            if (file.isDirectory) {
              scanDirectoryForFiles(file)
            } else if (extensions.contains(file.extension.lowercase())) {
              val fileInfo = mutableMapOf<String, Any?>()
              fileInfo["path"] = file.absolutePath
              // Try to extract embedded cover art
              try {
                val retriever = android.media.MediaMetadataRetriever()
                retriever.setDataSource(file.absolutePath)
                val art = retriever.embeddedPicture
                if (art != null) {
                  // Downscale the image to a small thumbnail (e.g., 128x128)
                  val bitmap = BitmapFactory.decodeByteArray(art, 0, art.size)
                  val thumb = Bitmap.createScaledBitmap(bitmap, 128, 128, true)
                  val outputStream = java.io.ByteArrayOutputStream()
                  thumb.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
                  fileInfo["cover"] = outputStream.toByteArray()
                } else {
                  fileInfo["cover"] = null
                }
                retriever.release()
              } catch (e: Exception) {
                fileInfo["cover"] = null
              }
              files.add(fileInfo)
            }
          }
        }
        val externalStorage = Environment.getExternalStorageDirectory()
        scanDirectoryForFiles(externalStorage)
        withContext(Dispatchers.Main) {
          result.success(files)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          result.error("FILE_SCAN_ERROR", "Error scanning files: ${e.message}", null)
        }
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
    scope.cancel()
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

