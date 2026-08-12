package com.example.media_manager

import android.Manifest
import android.content.Intent
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.*
import java.io.File

class MediaManagerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

  private lateinit var channel: MethodChannel
  private lateinit var appContext: Context
  private var binding: ActivityPluginBinding? = null

  private val job = SupervisorJob()
  private val scope = CoroutineScope(job + Dispatchers.IO)
  private val main = Handler(Looper.getMainLooper())

  private val scanner by lazy { MediaStoreScanner(appContext) }
  private val thumbs by lazy { ThumbnailEngine(appContext) }

  /** فقط یک‌بار پاسخ می‌دهد و همیشه روی ترد اصلی → جلوی «Reply already submitted» */
  private inner class SafeResult(private var delegate: Result?) : Result {
    override fun success(result: Any?) = post { it.success(result) }
    override fun error(code: String, msg: String?, details: Any?) = post { it.error(code, msg, details) }
    override fun notImplemented() = post { it.notImplemented() }
    private fun post(block: (Result) -> Unit) {
      val d = delegate ?: return
      delegate = null
      main.post { block(d) }
    }
  }

  override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
    appContext = b.applicationContext
    channel = MethodChannel(b.binaryMessenger, "media_manager")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, rawResult: Result) {
    val result = SafeResult(rawResult)
    when (call.method) {
      "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")

      "getMediaPage" -> {
        val type = parseType(call.argument<String>("type"))
        val exts = call.argument<List<String>>("extensions") ?: emptyList()
        val page = call.argument<Int>("page") ?: 0
        val size = (call.argument<Int>("pageSize") ?: 100).coerceIn(1, 500)
        scope.launch {
          runCatching { scanner.queryPage(type, exts, page * size, size, null) }
            .onSuccess { result.success(it) }
            .onFailure { result.error("QUERY_ERROR", it.message, null) }
        }
      }

      "getMediaCount" -> {
        val type = parseType(call.argument<String>("type"))
        val exts = call.argument<List<String>>("extensions") ?: emptyList()
        scope.launch {
          runCatching { scanner.count(type, exts, null) }
            .onSuccess { result.success(it) }
            .onFailure { result.error("QUERY_ERROR", it.message, null) }
        }
      }

      "getThumbnail" -> {
        val src = call.argument<String>("uri") ?: call.argument<String>("path")
        if (src == null) { result.error("INVALID_ARGUMENT", "uri/path required", null); return }
        val w = call.argument<Int>("width") ?: 256
        val h = call.argument<Int>("height") ?: w
        val stamp = (call.argument<Number>("dateModified") ?: 0).toLong()
        val kind = call.argument<String>("kind") ?: "image"
        scope.launch {
          val path = thumbs.thumbnail(
            this, src, w, h, stamp,
            isVideo = kind == "video", isAudio = kind == "audio"
          )
          result.success(path)
        }
      }

      "clearThumbnailCache" -> { scope.launch { thumbs.clear(); result.success(true) } }

      "getDirectories" -> scope.launch { result.success(publicDirectories()) }

      "getDirectoryContents" -> {
        val path = call.argument<String>("path") ?: Environment.getExternalStorageDirectory().path
        val page = call.argument<Int>("page") ?: 0
        val size = (call.argument<Int>("pageSize") ?: 200).coerceIn(1, 1000)
        scope.launch {
          runCatching { listDir(path, page, size) }
            .onSuccess { result.success(it) }
            .onFailure { result.error("FILE_ACCESS_ERROR", it.message, null) }
        }
      }

      "hasStoragePermission" -> result.success(hasPermission())
      "requestStoragePermission" -> requestPermission(result)
      "openAllFilesAccessSettings" -> { openAllFilesSettings(); result.success(true) }

      else -> result.notImplemented()
    }
  }

  private fun parseType(s: String?) = when (s) {
    "image" -> MediaStoreScanner.Type.IMAGE
    "video" -> MediaStoreScanner.Type.VIDEO
    "audio" -> MediaStoreScanner.Type.AUDIO
    "document" -> MediaStoreScanner.Type.DOCUMENT
    else -> MediaStoreScanner.Type.ANY
  }

  private fun listDir(path: String, page: Int, size: Int): List<Map<String, Any?>> {
    val dir = File(path)
    require(dir.isDirectory) { "Invalid directory: $path" }
    val all = (dir.listFiles() ?: emptyArray())
      .sortedWith(compareByDescending<File> { it.isDirectory }.thenBy { it.name.lowercase() })
    val from = page * size
    if (from >= all.size) return emptyList()
    return all.subList(from, minOf(from + size, all.size)).map { f ->
      mapOf(
        "name" to f.name,
        "path" to f.absolutePath,
        "isDirectory" to f.isDirectory,
        "size" to f.length(),
        "dateModified" to f.lastModified(),
        "extension" to if (f.isDirectory) "" else f.extension.lowercase()
      )
    }
  }

  private fun publicDirectories(): List<Map<String, String>> {
    val types = listOf(
      Environment.DIRECTORY_DCIM, Environment.DIRECTORY_PICTURES,
      Environment.DIRECTORY_MOVIES, Environment.DIRECTORY_MUSIC,
      Environment.DIRECTORY_DOWNLOADS, Environment.DIRECTORY_DOCUMENTS
    )
    val out = ArrayList<Map<String, String>>()
    types.forEach { t ->
      runCatching {
        val d = Environment.getExternalStoragePublicDirectory(t)
        if (d != null && d.exists()) out.add(mapOf("name" to t, "path" to d.absolutePath))
      }
    }
    Environment.getExternalStorageDirectory()?.let {
      out.add(0, mapOf("name" to "Internal Storage", "path" to it.absolutePath))
    }
    return out
  }

  private fun hasPermission(): Boolean = when {
    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
      listOf(
        Manifest.permission.READ_MEDIA_IMAGES,
        Manifest.permission.READ_MEDIA_VIDEO,
        Manifest.permission.READ_MEDIA_AUDIO
      ).any { ContextCompat.checkSelfPermission(appContext, it) == PackageManager.PERMISSION_GRANTED }
    Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
      Environment.isExternalStorageManager() ||
              ContextCompat.checkSelfPermission(appContext, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
    else ->
      ContextCompat.checkSelfPermission(appContext, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
  }

  /** یک لیسنر، یک requestCode، بدون امکان پاسخ دوباره */
  private fun requestPermission(result: Result) {
    if (hasPermission()) { result.success(true); return }
    val b = binding ?: run { result.error("NO_ACTIVITY", "Activity unavailable", null); return }

    val perms = when {
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> arrayOf(
        Manifest.permission.READ_MEDIA_IMAGES,
        Manifest.permission.READ_MEDIA_VIDEO,
        Manifest.permission.READ_MEDIA_AUDIO
      )
      else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    }

    val listener = object : PluginRegistry.RequestPermissionsResultListener {
      override fun onRequestPermissionsResult(code: Int, p: Array<String>, g: IntArray): Boolean {
        if (code != REQ_CODE) return false
        b.removeRequestPermissionsResultListener(this)
        result.success(g.isNotEmpty() && g.any { it == PackageManager.PERMISSION_GRANTED })
        return true
      }
    }
    b.addRequestPermissionsResultListener(listener)
    ActivityCompat.requestPermissions(b.activity, perms, REQ_CODE)
  }

  /** MANAGE_EXTERNAL_STORAGE فقط با Intent گرفته می‌شود، نه requestPermissions */
  private fun openAllFilesSettings() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
    val i = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
      Uri.parse("package:${appContext.packageName}"))
    (binding?.activity ?: appContext).startActivity(
      i.apply { if (binding == null) addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
    )
  }

  override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    job.cancel()            // بدون awaitTermination روی ترد اصلی
  }

  override fun onAttachedToActivity(b: ActivityPluginBinding) { binding = b }
  override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) { binding = b }
  override fun onDetachedFromActivity() { binding = null }
  override fun onDetachedFromActivityForConfigChanges() { binding = null }

  companion object { private const val REQ_CODE = 9713 }
}
