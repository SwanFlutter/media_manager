import Cocoa
import FlutterMacOS

public class MediaManagerPlugin: NSObject, FlutterPlugin {
    private var imageCache = NSCache<NSString, NSImage>()
    private var scanCancelled = false
    private var scanInProgress = false
    private var methodChannel: FlutterMethodChannel?

    // Permission constants
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

    // MARK: - Permission Management

    private func loadSavedPermissions() {
        if let savedBookmarks = UserDefaults.standard.dictionary(forKey: permissionKey) as? [String: Data] {
            for (urlString, bookmarkData) in savedBookmarks {
                if let url = URL(string: urlString) {
                    permissionBookmarks[url] = bookmarkData
                }
            }
        }

        // Start access to all stored permission bookmarks
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
                    // If stale, we'll need to create a new bookmark
                    if url.startAccessingSecurityScopedResource() {
                        createAndSaveBookmark(for: url)
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } catch {
                print("Error restoring bookmark access: \(error)")
                // Remove invalid bookmark
                permissionBookmarks.removeValue(forKey: url)
            }
        }

        // Save any changes made during restoration
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

    /**
     * Checks the status of storage permissions.
     *
     * Returns detailed information about all granted permissions, including:
     * - Whether any permissions exist
     * - List of accessible paths with details about each path:
     *   - path: The path that is accessible
     *   - canWrite: Whether write permission is available
     *   - isValid: Whether the security-scoped bookmark is still valid
     */
    private func checkPermissionStatus(result: @escaping FlutterResult) {
        let hasPermissions = !permissionBookmarks.isEmpty

        var accessiblePaths: [[String: Any]] = []
        for (url, bookmarkData) in permissionBookmarks {
            var isStale = false
            var isValid = false

            // Try to resolve the bookmark to check if it's still valid
            do {
                _ = try URL(resolvingBookmarkData: bookmarkData,
                         options: .withSecurityScope,
                         relativeTo: nil,
                         bookmarkDataIsStale: &isStale)
                isValid = true
            } catch {
                isValid = false
            }

            // Check if we can access the path
            if url.startAccessingSecurityScopedResource() {
                // Check write permission
                let canWrite = checkWritePermission(for: url.path)

                // Add path details
                accessiblePaths.append([
                    "path": url.path,
                    "canWrite": canWrite,
                    "isValid": isValid,
                    "isStale": isStale
                ])

                url.stopAccessingSecurityScopedResource()
            } else {
                // Path is no longer accessible
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

    /**
     * Requests permission to access files and directories on macOS.
     *
     * This method shows a folder picker dialog that allows the user to select a folder
     * to grant read/write access to. The method creates a security-scoped bookmark for
     * the selected folder, which allows the app to maintain access to the folder even
     * after the app is restarted.
     *
     * The result contains:
     * - granted: Boolean indicating if permission was granted
     * - path: String path of the selected folder (if granted)
     * - permanent: Boolean indicating if the permission is permanent (via security-scoped bookmark)
     * - canWrite: Boolean indicating if write access is available
     */
    private func requestMacStoragePermission(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.allowsMultipleSelection = true // Allow multiple folder selection
            openPanel.message = "Please select folders to grant access permissions"
            openPanel.prompt = "Grant Access"
            openPanel.title = "Media Manager - Folder Access"

            // Show the panel
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
                        // Start accessing the resource with security scope
                        let canAccess = url.startAccessingSecurityScopedResource()

                        if canAccess {
                            // Create and store the security-scoped bookmark
                            let success = self.createAndSaveBookmark(for: url)

                            // Check write permission
                            let canWrite = self.checkWritePermission(for: url.path)

                            // Add to successful paths
                            successfulPaths.append([
                                "path": url.path,
                                "permanent": success,
                                "canWrite": canWrite
                            ])

                            // Stop accessing the resource
                            url.stopAccessingSecurityScopedResource()
                        } else {
                            // Could access but not permanently
                            successfulPaths.append([
                                "path": url.path,
                                "permanent": false,
                                "canWrite": false
                            ])
                        }
                    }

                    // Return results
                    if successfulPaths.isEmpty {
                        result(["granted": false, "message": "Failed to access selected folders"])
                    } else {
                        result([
                            "granted": true,
                            "paths": successfulPaths
                        ])
                    }
                } else {
                    // User cancelled
                    result(["granted": false, "message": "User cancelled the permission request"])
                }
            }
        }
    }

    /**
     * Checks if write permission is available for the specified path.
     *
     * @param path The path to check for write permission
     * @return true if write permission is available, false otherwise
     */
    private func checkWritePermission(for path: String) -> Bool {
        let testFilePath = (path as NSString).appendingPathComponent(".media_manager_write_test")
        let fileManager = FileManager.default

        // Try to create a test file
        if fileManager.createFile(atPath: testFilePath, contents: Data(), attributes: nil) {
            // If successful, remove the test file
            do {
                try fileManager.removeItem(atPath: testFilePath)
                return true
            } catch {
                print("Could create test file but failed to delete it: \(error)")
                return true // Still return true since we could write
            }
        }

        return false
    }

    /**
     * Checks if a specific path is accessible with current permissions.
     *
     * @param path The path to check for accessibility
     * @return true if the path is accessible, false otherwise
     */
    private func isPathAccessible(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)

        // Check if any of our bookmarks cover this path
        for (bookmarkURL, _) in permissionBookmarks {
            if path.hasPrefix(bookmarkURL.path) {
                if bookmarkURL.startAccessingSecurityScopedResource() {
                    defer {
                        bookmarkURL.stopAccessingSecurityScopedResource()
                    }
                    return FileManager.default.isReadableFile(atPath: path)
                }
            }
        }

        // If no bookmark covers this path, check if it's readable directly
        return FileManager.default.isReadableFile(atPath: path)
    }

    /**
     * Checks if a specific path is accessible and returns detailed information.
     *
     * This method is exposed to Flutter and provides information about:
     * - Whether the path is accessible (readable)
     * - Whether the path is writable
     * - Which permission bookmark is providing access (if any)
     *
     * @param path The path to check
     * @param result The Flutter result callback
     */
    private func checkPathAccessibility(path: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let url = URL(fileURLWithPath: path)

            // Default values
            var isAccessible = false
            var isWritable = false
            var permissionSource: String? = nil
            var needsPermission = false

            // First check if the file exists
            let fileExists = fileManager.fileExists(atPath: path)

            // Check if any of our bookmarks cover this path
            var usedSecurityScope = false
            for (bookmarkURL, _) in self.permissionBookmarks where path.hasPrefix(bookmarkURL.path) {
                if bookmarkURL.startAccessingSecurityScopedResource() {
                    usedSecurityScope = true
                    permissionSource = bookmarkURL.path

                    // Check read access
                    isAccessible = fileExists && fileManager.isReadableFile(atPath: path)

                    // Check write access if the file exists
                    if fileExists {
                        isWritable = fileManager.isWritableFile(atPath: path)
                    } else {
                        // For directories that don't exist, try to check parent directory
                        let parentPath = (path as NSString).deletingLastPathComponent
                        if fileManager.fileExists(atPath: parentPath) {
                            isWritable = fileManager.isWritableFile(atPath: parentPath)
                        }
                    }

                    bookmarkURL.stopAccessingSecurityScopedResource()
                    break
                }
            }

            // If no security scope was used, check direct access
            if !usedSecurityScope {
                if fileExists {
                    isAccessible = fileManager.isReadableFile(atPath: path)
                    isWritable = fileManager.isWritableFile(atPath: path)
                    permissionSource = "direct"
                } else {
                    // For directories that don't exist, try to check parent directory
                    let parentPath = (path as NSString).deletingLastPathComponent
                    if fileManager.fileExists(atPath: parentPath) {
                        isAccessible = fileManager.isReadableFile(atPath: parentPath)
                        isWritable = fileManager.isWritableFile(atPath: parentPath)
                        permissionSource = "direct"
                    }
                }

                // Check if this path would need permission (outside user directory)
                let homePath = fileManager.homeDirectoryForCurrentUser.path
                needsPermission = !path.hasPrefix(homePath) || path.contains("/Library/") || path.contains("/Applications/")
            }

            // Prepare result
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

            // Check if we need to use security-scoped access
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
                        // Try to use security-scoped resource access if available
                        var usingSecurityScope = false
                        for (url, _) in self.permissionBookmarks where startURL.path.hasPrefix(url.path) {
                            usingSecurityScope = url.startAccessingSecurityScopedResource()
                            if usingSecurityScope {
                                // Start file search with security scope
                                self.performFileSearch(startURL: startURL, extensions: extensions, result: result)
                                // Make sure to release the security scope after search completes
                                url.stopAccessingSecurityScopedResource()
                            }
                            break
                        }

                        // If no security scope was used, proceed normally
                        if !usingSecurityScope {
                            self.performFileSearch(startURL: startURL, extensions: extensions, result: result)
                        }

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
            let maxDepth = 10 // Limit search depth
            let maxFiles = 1000 // Limit number of files
            var filesFound = 0
            var lastProgressUpdate = Date()

            func scanDirectory(_ url: URL, depth: Int) {
                // Check if scan was cancelled
                if self.scanCancelled || filesFound >= maxFiles {
                    return
                }

                // If we've reached max depth, return
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

                        // Check files and add to results
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
                            // Check folder access before scanning
                            if fileManager.isReadableFile(atPath: item.path) {
                                scanDirectory(item, depth: depth + 1)
                            }
                        }
                    }
                } catch {
                    // Log errors but allow search to continue
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