import Cocoa
import FlutterMacOS

public class MediaManagerPlugin: NSObject, FlutterPlugin {
    private var imageCache = NSCache<NSString, NSImage>()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "media_manager", binaryMessenger: registrar.messenger)
        let instance = MediaManagerPlugin()
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

        case "requestStoragePermission":
            // On macOS, we don't need to request storage permission
            result(true)

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
      "zbrush"
    ]
    )

        case "getAllZipFiles":
            getAllFilesByType(result: result, extensions: ["zip", "rar"])

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getDirectories(result: @escaping FlutterResult) {
        let fileManager = FileManager.default
        let homePath = fileManager.homeDirectoryForCurrentUser

        do {
            let contents = try fileManager.contentsOfDirectory(at: homePath,
                                                              includingPropertiesForKeys: nil,
                                                              options: [.skipsHiddenFiles])

            let directories = contents.filter { $0.hasDirectoryPath }
                .map { url -> [String: Any] in
                    return [
                        "name": url.lastPathComponent,
                        "path": url.path
                    ]
                }
                .sorted { ($0["name"] as! String) < ($1["name"] as! String) }

            result(directories)
        } catch {
            result(FlutterError(code: "DIRECTORY_ACCESS_ERROR",
                              message: error.localizedDescription,
                              details: nil))
        }
    }

    private func getDirectoryContents(path: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let directoryURL = URL(fileURLWithPath: path)

            do {
                // Only using fileSizeKey to avoid macOS version compatibility issues
                let contents = try fileManager.contentsOfDirectory(at: directoryURL,
                                                                  includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                                                                  options: [.skipsHiddenFiles])

                let items = contents.map { url -> [String: Any] in
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
                        if let date = try url.resourceValues(forKeys: [.creationDateKey]).creationDate {
                            lastModified = date.timeIntervalSince1970
                        }
                    } catch {
                        print("Error getting creation date: \(error)")
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
        if let cachedImage = imageCache.object(forKey: path as NSString) {
            if let imageData = convertImageToData(cachedImage) {
                result(imageData)
                return
            }
        }

        if let image = NSImage(contentsOfFile: path) {
            let resizedImage = resizeImage(image, targetSize: NSSize(width: 800, height: 800))
            imageCache.setObject(resizedImage, forKey: path as NSString)

            if let imageData = convertImageToData(resizedImage) {
                result(imageData)
            } else {
                result(FlutterError(code: "IMAGE_COMPRESSION_ERROR",
                                  message: "Failed to compress image",
                                  details: nil))
            }
        } else {
            result(FlutterError(code: "IMAGE_LOAD_ERROR",
                              message: "Failed to load image",
                              details: nil))
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

    private func getAllFilesByType(result: @escaping FlutterResult, extensions: [String]) {
        let fileManager = FileManager.default
        let homePath = fileManager.homeDirectoryForCurrentUser

        var files: [String] = []

        func scanDirectory(_ url: URL) {
            do {
                let contents = try fileManager.contentsOfDirectory(at: url,
                                                                  includingPropertiesForKeys: nil,
                                                                  options: [.skipsHiddenFiles])

                for item in contents {
                    if item.hasDirectoryPath {
                        scanDirectory(item)
                    } else if extensions.contains(item.pathExtension.lowercased()) {
                        files.append(item.path)
                    }
                }
            } catch {
                print("Error scanning directory: \(error.localizedDescription)")
            }
        }

        scanDirectory(homePath)
        result(files)
    }

    private func getFileType(_ extension: String) -> String {
        switch `extension` {
        case "jpg", "jpeg", "png", "gif", "bmp", "webp":
            return "image"
        case "mp4", "mov", "m4v":
            return "video"
        case "mp3", "wav", "m4a":
            return "audio"
        case "pdf", "doc", "docx", "txt", "rtf":
            return "document"
        case "zip", "rar":
            return "zip"
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
