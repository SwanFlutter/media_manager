import Cocoa
import FlutterMacOS

public class MediaManagerPlugin: NSObject, FlutterPlugin {
    private var imageCache = NSCache<NSString, NSImage>()
    private var scanCancelled = false
    private var scanInProgress = false
    private var methodChannel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "media_manager", binaryMessenger: registrar.messenger)
        let instance = MediaManagerPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
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

        case "requestStoragePermission":
            // On macOS, we need to use a open panel dialog to get user permission
            requestStoragePermission(result: result)

        case "getAllImages":
            getAllFilesByType(result: result, extensions: ["jpg", "jpeg", "png", "gif", "bmp", "webp"])

        case "getAllVideos":
            getAllFilesByType(result: result, extensions: ["mp4", "mov", "m4v"])

        case "getAllAudio":
            getAllFilesByType(result: result, extensions: ["mp3", "wav", "m4a"])

        case "getAllDocuments":
            getAllFilesByType(result: result,  extensions: [
                // Document formats
                "pdf", "doc", "docx", "docm", "dot", "dotx", "dotm",
                "txt", "rtf", "odt", "ott", "odm", "oth",
                "xml", "html", "htm", "xhtml", "mhtml",
                "epub", "mobi", "azw", "fb2",
                
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
                
                // Other document formats
                "md", "markdown", "tex", "log", "pages", "wpd", "wps",
                "abw", "zabw", "123", "602", "wk1", "wk3", "wk4", "wq1",
                "wq2", "xlw", "pmd", "sxw", "stw", "vor", "sxg", "otg"
            ])

        case "getAllZipFiles":
            getAllFilesByType(result: result, extensions: ["zip", "rar"])

        default:
            result(FlutterMethodNotImplemented)
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

            do {
                // Check if directory is readable
                guard fileManager.isReadableFile(atPath: path) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "PERMISSION_DENIED",
                                        message: "Cannot access directory: Permission denied",
                                        details: nil))
                    }
                    return
                }
                
                // Only using fileSizeKey to avoid macOS version compatibility issues
                let contents = try fileManager.contentsOfDirectory(at: directoryURL,
                                                                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
                                                                options: [.skipsHiddenFiles])

                let items = contents.compactMap { url -> [String: Any]? in
                    // Skip files we can't read
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
                        // Try content modification date first, fall back to creation date
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
            // Check cache first
            if let cachedImage = self.imageCache.object(forKey: path as NSString) {
                if let imageData = self.convertImageToData(cachedImage) {
                    DispatchQueue.main.async {
                        result(imageData)
                    }
                    return
                }
            }

            // Check if file exists and is readable
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: path), fileManager.isReadableFile(atPath: path) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "FILE_NOT_FOUND",
                                      message: "File does not exist or is not readable",
                                      details: nil))
                }
                return
            }
            
            // Load and process image
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

    private func requestStoragePermission(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.allowsMultipleSelection = false
            openPanel.message = "Please select a folder to grant access permissions"
            openPanel.prompt = "Grant Access"
            
            openPanel.begin { response in
                if response == .OK {
                    // User granted access to a specific directory
                    if let url = openPanel.url {
                        // You could store this URL for future use with security-scoped bookmarks
                        result(["granted": true, "path": url.path])
                    } else {
                        result(["granted": false])
                    }
                } else {
                    result(["granted": false])
                }
            }
        }
    }

    private func getAllFilesByType(result: @escaping FlutterResult, extensions: [String]) {
        // Prevent multiple concurrent scans
        guard !scanInProgress else {
            result(FlutterError(code: "SCAN_IN_PROGRESS",
                              message: "A file scan is already in progress",
                              details: nil))
            return
        }
        
        scanInProgress = true
        scanCancelled = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            
            // Instead of starting from the home directory, ask user to choose directory
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
                        self.performFileSearch(startURL: startURL, extensions: extensions, result: result)
                    } else {
                        self.scanInProgress = false
                        result([]) // Return empty array if user cancels
                    }
                }
            }
        }
    }
    
    private func performFileSearch(startURL: URL, extensions: [String], result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            var files: [String] = []
            let maxDepth = 10 // محدود کردن عمق جستجو
            let maxFiles = 1000 // محدود کردن تعداد فایل‌ها
            var filesFound = 0
            var lastProgressUpdate = Date()
            
            func scanDirectory(_ url: URL, depth: Int) {
                // Check if scan was cancelled
                if self.scanCancelled || filesFound >= maxFiles {
                    return
                }
                
                // اگر به حداکثر عمق رسیدیم، برگردیم
                if depth > maxDepth {
                    return
                }
                
                // Send progress update every 0.5 seconds
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
                    // Check if directory is readable
                    guard fileManager.isReadableFile(atPath: url.path) else {
                        return
                    }
                    
                    let contents = try fileManager.contentsOfDirectory(at: url,
                                                                   includingPropertiesForKeys: nil,
                                                                   options: [.skipsHiddenFiles])
                    
                    for item in contents {
                        // Check if scan was cancelled
                        if self.scanCancelled || filesFound >= maxFiles {
                            return
                        }
                        
                        // بررسی فایل‌ها و افزودن به نتایج
                        if !item.hasDirectoryPath {
                            if extensions.contains(item.pathExtension.lowercased()) {
                                files.append(item.path)
                                filesFound += 1
                                
                                // Batch send results every 20 files
                                if filesFound % 20 == 0 {
                                    let currentBatch = Array(files[(filesFound - 20)..<filesFound])
                                    DispatchQueue.main.async {
                                        self.methodChannel?.invokeMethod("fileSearchBatchResult", arguments: currentBatch)
                                    }
                                }
                            }
                        } else {
                            // بررسی دسترسی پوشه قبل از اسکن
                            if fileManager.isReadableFile(atPath: item.path) {
                                scanDirectory(item, depth: depth + 1)
                            }
                        }
                    }
                } catch {
                    // خطاها را ثبت می‌کنیم اما اجازه می‌دهیم جستجو ادامه یابد
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
                    // Send final complete results
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