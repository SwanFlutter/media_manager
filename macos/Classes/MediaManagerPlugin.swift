import Cocoa
import FlutterMacOS
import AVFoundation

public class MediaManagerPlugin: NSObject, FlutterPlugin {
    private var imageCache = NSCache<NSString, NSImage>()
    private var scanCancelled = false
    private var scanInProgress = false
    private var methodChannel: FlutterMethodChannel?
    private let permissionKey = "MediaManagerPermissionStatus"
    private var permissionBookmarks: [URL: Data] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "media_manager", binaryMessenger: registrar.messenger)
        let instance = MediaManagerPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.loadSavedPermissions()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
        case "getDirectories":
            getDirectories(result: result)
        case "getDirectoryContents":
            if let args = call.arguments as? [String: Any],
               let path = args["path"] as? String {
                getDirectoryContents(path: path, result: result)
            } else {
                result(FlutterError(code: "INVALID_PATH",
                                  message: "Invalid directory path",
                                  details: nil))
            }
        case "getImagePreview":
            if let args = call.arguments as? [String: Any],
               let path = args["path"] as? String {
                getImagePreview(path: path, result: result)
            } else {
                result(FlutterError(code: "INVALID_PATH",
                                  message: "Invalid image path",
                                  details: nil))
            }
        case "clearImageCache":
            clearImageCache()
            result(true)
        case "cancelFileSearch":
            cancelFileSearch()
            result(true)
        case "requestMacStoragePermission":
            requestMacStoragePermission(result: result)
        case "checkPermissionStatus":
            checkPermissionStatus(result: result)
        case "checkPathAccessibility":
            if let args = call.arguments as? [String: Any],
               let path = args["path"] as? String {
                checkPathAccessibility(path: path, result: result)
            } else {
                result(FlutterError(code: "INVALID_PATH",
                                  message: "Invalid path",
                                  details: nil))
            }
        case "getAllImages":
            getAllFilesByType(result: result, extensions: ["jpg", "jpeg", "png", "gif", "bmp", "webp"], isAudio: false)
        case "getAllVideos":
            getAllFilesByType(result: result, extensions: ["mp4", "mov", "m4v"], isAudio: false)
        case "getAllAudio":
            // ✅ اضافه کردن پشتیبانی کاور برای فایل‌های صوتی
            getAllFilesByType(result: result, extensions: ["mp3", "wav", "m4a", "aac", "ogg", "flac"], isAudio: true)
        case "getAllDocuments":
            getAllFilesByType(result: result, extensions: [
                "pdf", "doc", "docx", "docm", "dot", "dotx", "dotm",
                "txt", "rtf", "odt", "ott", "odm", "oth",
                "xml", "html", "htm", "xhtml", "mhtml",
                "epub", "mobi", "azw", "fb2",
                "xls", "xlsx", "xlsm", "xlsb", "xlt", "xltx", "xltm",
                "ods", "ots", "csv",
                "ppt", "pptx", "pptm", "pps", "ppsx", "ppsm",
                "pot", "potx", "potm", "odp", "otp",
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
                "vue", "svelte", "astro", "php", "phtml", "twig",
                "mustache", "hbs", "ejs", "haml", "scss", "sass",
                "less", "styl", "stylus", "coffee", "litcoffee",
                "graphql", "gql", "wasm", "wat",
                "md", "markdown", "tex", "log", "pages", "wpd", "wps",
                "abw", "zabw", "123", "602", "wk1", "wk3", "wk4", "wq1",
                "wq2", "xlw", "pmd", "sxw", "stw", "vor", "sxg", "otg"
            ], isAudio: false)
        case "getAllZipFiles":
            getAllFilesByType(result: result, extensions: ["zip", "rar"], isAudio: false)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ... [همه متدهای permission و directory به همان شکل قبلی] ...

    private func loadSavedPermissions() {
        if let savedBookmarks = UserDefaults.standard.dictionary(forKey: permissionKey) as? [String: Data] {
            for (urlString, bookmarkData) in savedBookmarks {
                if let url = URL(string: urlString) {
                    permissionBookmarks[url] = bookmarkData
                }
            }
        }
        reestablishPermissionAccess()
    }

    private func savePermissions() {
        var bookmarkDict: [String: Data] = [:]
        for (url, data) in permissionBookmarks {
            bookmarkDict[url.absoluteString] = data
        }
        UserDefaults.standard.set(bookmarkDict, forKey: permissionKey)
    }

    private func reestablishPermissionAccess() {
        for (url, bookmarkData) in permissionBookmarks {
            var isStale = false
            do {
                _ = try URL(resolvingBookmarkData: bookmarkData,
                         options: .withSecurityScope,
                         relativeTo: nil,
                         bookmarkDataIsStale: &isStale)
                if isStale {
                    if url.startAccessingSecurityScopedResource() {
                        createAndSaveBookmark(for: url)
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } catch {
                print("Error restoring bookmark access: \(error)")
                permissionBookmarks.removeValue(forKey: url)
            }
        }
        savePermissions()
    }

    private func createAndSaveBookmark(for url: URL) -> Bool {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope,
                                                  includingResourceValuesForKeys: nil,
                                                  relativeTo: nil)
            permissionBookmarks[url] = bookmarkData
            savePermissions()
            return true
        } catch {
            print("Failed to create security bookmark: \(error)")
            return false
        }
    }

    private func checkPermissionStatus(result: @escaping FlutterResult) {
        let hasPermissions = !permissionBookmarks.isEmpty
        var accessiblePaths: [[String: Any]] = []
        for (url, bookmarkData) in permissionBookmarks {
            var isStale = false
            var isValid = false
            do {
                _ = try URL(resolvingBookmarkData: bookmarkData,
                         options: .withSecurityScope,
                         relativeTo: nil,
                         bookmarkDataIsStale: &isStale)
                isValid = true
            } catch {
                isValid = false
            }
            if url.startAccessingSecurityScopedResource() {
                let canWrite = checkWritePermission(for: url.path)
                accessiblePaths.append([
                    "path": url.path,
                    "canWrite": canWrite,
                    "isValid": isValid,
                    "isStale": isStale
                ])
                url.stopAccessingSecurityScopedResource()
            } else {
                accessiblePaths.append([
                    "path": url.path,
                    "canWrite": false,
                    "isValid": false,
                    "isStale": true
                ])
            }
        }
        let response: [String: Any] = [
            "hasPermissions": hasPermissions,
            "paths": accessiblePaths
        ]
        result(response)
    }

    private func requestMacStoragePermission(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.allowsMultipleSelection = true
            openPanel.message = "Please select folders to grant access permissions"
            openPanel.prompt = "Grant Access"
            openPanel.title = "Media Manager - Folder Access"
            openPanel.begin { [weak self] response in
                guard let self = self else { return }
                if response == .OK {
                    var successfulPaths: [[String: Any]] = []
                    let urls = openPanel.urls
                    if urls.isEmpty {
                        result(["granted": false, "message": "No folders were selected"])
                        return
                    }
                    for url in urls {
                        let canAccess = url.startAccessingSecurityScopedResource()
                        if canAccess {
                            let success = self.createAndSaveBookmark(for: url)
                            let canWrite = self.checkWritePermission(for: url.path)
                            successfulPaths.append([
                                "path": url.path,
                                "permanent": success,
                                "canWrite": canWrite
                            ])
                            url.stopAccessingSecurityScopedResource()
                        } else {
                            successfulPaths.append([
                                "path": url.path,
                                "permanent": false,
                                "canWrite": false
                            ])
                        }
                    }
                    if successfulPaths.isEmpty {
                        result(["granted": false, "message": "Failed to access selected folders"])
                    } else {
                        result([
                            "granted": true,
                            "paths": successfulPaths
                        ])
                    }
                } else {
                    result(["granted": false, "message": "User cancelled the permission request"])
                }
            }
        }
    }

    private func checkWritePermission(for path: String) -> Bool {
        let testFilePath = (path as NSString).appendingPathComponent(".media_manager_write_test")
        let fileManager = FileManager.default
        if fileManager.createFile(atPath: testFilePath, contents: Data(), attributes: nil) {
            do {
                try fileManager.removeItem(atPath: testFilePath)
                return true
            } catch {
                print("Could create test file but failed to delete it: \(error)")
                return true
            }
        }
        return false
    }

    private func checkPathAccessibility(path: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let url = URL(fileURLWithPath: path)
            var isAccessible = false
            var isWritable = false
            var permissionSource: String? = nil
            var needsPermission = false
            let fileExists = fileManager.fileExists(atPath: path)
            var usedSecurityScope = false
            for (bookmarkURL, _) in self.permissionBookmarks where path.hasPrefix(bookmarkURL.path) {
                if bookmarkURL.startAccessingSecurityScopedResource() {
                    usedSecurityScope = true
                    permissionSource = bookmarkURL.path
                    isAccessible = fileExists && fileManager.isReadableFile(atPath: path)
                    if fileExists {
                        isWritable = fileManager.isWritableFile(atPath: path)
                    } else {
                        let parentPath = (path as NSString).deletingLastPathComponent
                        if fileManager.fileExists(atPath: parentPath) {
                            isWritable = fileManager.isWritableFile(atPath: parentPath)
                        }
                    }
                    bookmarkURL.stopAccessingSecurityScopedResource()
                    break
                }
            }
            if !usedSecurityScope {
                if fileExists {
                    isAccessible = fileManager.isReadableFile(atPath: path)
                    isWritable = fileManager.isWritableFile(atPath: path)
                    permissionSource = "direct"
                } else {
                    let parentPath = (path as NSString).deletingLastPathComponent
                    if fileManager.fileExists(atPath: parentPath) {
                        isAccessible = fileManager.isReadableFile(atPath: parentPath)
                        isWritable = fileManager.isWritableFile(atPath: parentPath)
                        permissionSource = "direct"
                    }
                }
                let homePath = fileManager.homeDirectoryForCurrentUser.path
                needsPermission = !path.hasPrefix(homePath) || path.contains("/Library/") || path.contains("/Applications/")
            }
            let response: [String: Any] = [
                "path": path,
                "exists": fileExists,
                "isAccessible": isAccessible,
                "isWritable": isWritable,
                "permissionSource": permissionSource ?? "none",
                "needsPermission": needsPermission
            ]
            DispatchQueue.main.async {
                result(response)
            }
        }
    }

    private func getDirectories(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let homePath = fileManager.homeDirectoryForCurrentUser
            do {
                let contents = try fileManager.contentsOfDirectory(at: homePath,
                                                                includingPropertiesForKeys: nil,
                                                                options: [.skipsHiddenFiles])
                let directories = contents.filter { $0.hasDirectoryPath && fileManager.isReadableFile(atPath: $0.path) }
                    .map { url -> [String: Any] in
                        return [
                            "name": url.lastPathComponent,
                            "path": url.path
                        ]
                    }
                    .sorted { ($0["name"] as! String) < ($1["name"] as! String) }
                DispatchQueue.main.async {
                    result(directories)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "DIRECTORY_ACCESS_ERROR",
                                    message: error.localizedDescription,
                                    details: nil))
                }
            }
        }
    }

    private func getDirectoryContents(path: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let directoryURL = URL(fileURLWithPath: path)
            var usingSecurityScope = false
            for (url, _) in self.permissionBookmarks where directoryURL.path.hasPrefix(url.path) {
                usingSecurityScope = url.startAccessingSecurityScopedResource()
                defer {
                    if usingSecurityScope {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                break
            }
            do {
                guard fileManager.isReadableFile(atPath: path) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "PERMISSION_DENIED",
                                        message: "Cannot access directory: Permission denied",
                                        details: nil))
                    }
                    return
                }
                let contents = try fileManager.contentsOfDirectory(at: directoryURL,
                                                                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
                                                                options: [.skipsHiddenFiles])
                let items = contents.compactMap { url -> [String: Any]? in
                    guard fileManager.isReadableFile(atPath: url.path) else {
                        return nil
                    }
                    let isDirectory = url.hasDirectoryPath
                    var fileSize: Int64 = 0
                    do {
                        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                        fileSize = Int64(resourceValues.fileSize ?? 0)
                    } catch {
                        print("Error getting file size: \(error)")
                    }
                    let fileExt = url.pathExtension.lowercased()
                    var lastModified: TimeInterval = 0
                    do {
                        let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
                        if let date = resourceValues.contentModificationDate {
                            lastModified = date.timeIntervalSince1970
                        } else if let date = resourceValues.creationDate {
                            lastModified = date.timeIntervalSince1970
                        }
                    } catch {
                        print("Error getting date: \(error)")
                    }
                    return [
                        "name": url.lastPathComponent,
                        "path": url.path,
                        "isDirectory": isDirectory,
                        "type": isDirectory ? "directory" : self.getFileType(fileExt),
                        "extension": fileExt,
                        "size": fileSize,
                        "readableSize": self.formatFileSize(fileSize),
                        "lastModified": lastModified
                    ]
                }
                .sorted { (($0["isDirectory"] as! Bool) && !($1["isDirectory"] as! Bool)) ||
                        (($0["isDirectory"] as! Bool) == ($1["isDirectory"] as! Bool) &&
                         ($0["name"] as! String) < ($1["name"] as! String)) }
                DispatchQueue.main.async {
                    result(items)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "FILE_ACCESS_ERROR",
                                      message: error.localizedDescription,
                                      details: nil))
                }
            }
        }
    }

    private func getImagePreview(path: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let cachedImage = self.imageCache.object(forKey: path as NSString) {
                if let imageData = self.convertImageToData(cachedImage) {
                    DispatchQueue.main.async {
                        result(imageData)
                    }
                    return
                }
            }
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: path), fileManager.isReadableFile(atPath: path) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "FILE_NOT_FOUND",
                                      message: "File does not exist or is not readable",
                                      details: nil))
                }
                return
            }
            if let image = NSImage(contentsOfFile: path) {
                let resizedImage = self.resizeImage(image, targetSize: NSSize(width: 800, height: 800))
                self.imageCache.setObject(resizedImage, forKey: path as NSString)
                if let imageData = self.convertImageToData(resizedImage) {
                    DispatchQueue.main.async {
                        result(imageData)
                    }
                } else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "IMAGE_COMPRESSION_ERROR",
                                          message: "Failed to compress image",
                                          details: nil))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "IMAGE_LOAD_ERROR",
                                      message: "Failed to load image",
                                      details: nil))
                }
            }
        }
    }

    private func convertImageToData(_ image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
    }

    private func clearImageCache() {
        imageCache.removeAllObjects()
    }

    private func cancelFileSearch() {
        scanCancelled = true
    }

    // ✅ متد اصلی با پشتیبانی کاور
    private func getAllFilesByType(result: @escaping FlutterResult, extensions: [String], isAudio: Bool) {
        guard !scanInProgress else {
            result(FlutterError(code: "SCAN_IN_PROGRESS",
                              message: "A file scan is already in progress",
                              details: nil))
            return
        }
        scanInProgress = true
        scanCancelled = false
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.sync {
                let openPanel = NSOpenPanel()
                openPanel.canChooseDirectories = true
                openPanel.canChooseFiles = false
                openPanel.allowsMultipleSelection = false
                openPanel.message = "Please select a folder to search for files"
                openPanel.prompt = "Search"
                openPanel.begin { [weak self] response in
                    guard let self = self else { return }
                    if response == .OK, let startURL = openPanel.url {
                        var usingSecurityScope = false
                        for (url, _) in self.permissionBookmarks where startURL.path.hasPrefix(url.path) {
                            usingSecurityScope = url.startAccessingSecurityScopedResource()
                            if usingSecurityScope {
                                self.performFileSearch(startURL: startURL, extensions: extensions, result: result, isAudio: isAudio)
                                url.stopAccessingSecurityScopedResource()
                            }
                            break
                        }
                        if !usingSecurityScope {
                            self.performFileSearch(startURL: startURL, extensions: extensions, result: result, isAudio: isAudio)
                        }
                    } else {
                        self.scanInProgress = false
                        result([])
                    }
                }
            }
        }
    }

    // ✅ متد جستجو با پشتیبانی کاور
    private func performFileSearch(startURL: URL, extensions: [String], result: @escaping FlutterResult, isAudio: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fileManager = FileManager.default
            var files: [Any] = [] // ✅ تغییر از [String] به [Any]
            let maxDepth = 10
            let maxFiles = 1000
            var filesFound = 0
            var lastProgressUpdate = Date()
            
            func scanDirectory(_ url: URL, depth: Int) {
                if self.scanCancelled || filesFound >= maxFiles {
                    return
                }
                if depth > maxDepth {
                    return
                }
                let now = Date()
                if now.timeIntervalSince(lastProgressUpdate) > 0.5 {
                    lastProgressUpdate = now
                    DispatchQueue.main.async {
                        self.methodChannel?.invokeMethod("fileSearchProgress", arguments: [
                            "filesFound": filesFound,
                            "currentDirectory": url.path
                        ])
                    }
                }
                do {
                    guard fileManager.isReadableFile(atPath: url.path) else {
                        return
                    }
                    let contents = try fileManager.contentsOfDirectory(at: url,
                                                                   includingPropertiesForKeys: nil,
                                                                   options: [.skipsHiddenFiles])
                    for item in contents {
                        if self.scanCancelled || filesFound >= maxFiles {
                            return
                        }
                        if !item.hasDirectoryPath {
                            if extensions.contains(item.pathExtension.lowercased()) {
                                // ✅ اگر فایل صوتی است، کاور را استخراج کن
                                if isAudio {
                                    var coverData: Data? = nil
                                    do {
                                        let asset = AVAsset(url: item)
                                        for meta in asset.commonMetadata {
                                            if meta.commonKey?.rawValue == "artwork", let value = meta.value as? Data {
                                                coverData = value
                                                break
                                            }
                                        }
                                    } catch {
                                        coverData = nil
                                    }
                                    
                                    files.append([
                                        "path": item.path,
                                        "cover": coverData != nil ? FlutterStandardTypedData(bytes: coverData!) : nil
                                    ])
                                } else {
                                    // سایر فایل‌ها فقط مسیر را برگردانند
                                    files.append(item.path)
                                }
                                
                                filesFound += 1
                                if filesFound % 20 == 0 {
                                    let startIndex = max(0, filesFound - 20)
                                    let endIndex = min(files.count, filesFound)
                                    let currentBatch = Array(files[startIndex..<endIndex])
                                    DispatchQueue.main.async {
                                        self.methodChannel?.invokeMethod("fileSearchBatchResult", arguments: currentBatch)
                                    }
                                }
                            }
                        } else {
                            if fileManager.isReadableFile(atPath: item.path) {
                                scanDirectory(item, depth: depth + 1)
                            }
                        }
                    }
                } catch {
                    print("Error scanning directory \(url.path): \(error.localizedDescription)")
                }
            }
            scanDirectory(startURL, depth: 0)
            self.scanInProgress = false
            DispatchQueue.main.async {
                if self.scanCancelled {
                    result(FlutterError(code: "SCAN_CANCELLED",
                                      message: "File scan was cancelled",
                                      details: nil))
                } else {
                    result(files)
                }
            }
        }
    }

    private func getFileType(_ extension: String) -> String {
        switch `extension` {
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "tiff", "tif", "heic", "heif":
            return "image"
        case "mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm":
            return "video"
        case "mp3", "wav", "m4a", "aac", "ogg", "flac", "alac", "aiff":
            return "audio"
        case "pdf", "doc", "docx", "txt", "rtf", "odt", "pages", "epub", "md", "markdown":
            return "document"
        case "zip", "rar", "7z", "tar", "gz", "bz2":
            return "archive"
        case "ppt", "pptx", "key":
            return "presentation"
        case "xls", "xlsx", "numbers", "csv":
            return "spreadsheet"
        case "html", "htm", "css", "js", "json", "xml":
            return "code"
        default:
            return "other"
        }
    }

    private func formatFileSize(_ size: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var fileSize = Double(size)
        var unitIndex = 0
        while fileSize >= 1024 && unitIndex < units.count - 1 {
            fileSize /= 1024
            unitIndex += 1
        }
        return String(format: "%.2f %@", fileSize, units[unitIndex])
    }

    private func resizeImage(_ image: NSImage, targetSize: NSSize) -> NSImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        newImage.unlockFocus()
        return newImage
    }
}