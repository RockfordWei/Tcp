//
//  HTTP11.swift
//  
//
//  Created by Rocky Wei on 2/20/23.
//

import Foundation

open class HttpResponse {
    internal let version = "HTTP/1.0"
    public var headers: [String: String] = [:]
    internal let body: Data
    public let contentLength: Int
    internal var code = 200
    public init(raw: Data) {
        body = raw
        contentLength = raw.count
    }
    public init(path: String) {
        headers["Content-Type"] = path.sniffMIME()
        do {
            contentLength = try FileManager.default.size(of: path)
            body = Data()
        } catch {
            let nsError = error as NSError
            let errors = nsError.domain + "\n" + nsError.userInfo.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            body = errors.data(using: .utf8) ?? Data()
            contentLength = body.count
            code = nsError.code
        }
    }
    public convenience init(content: String? = nil) {
        let data = content?.data(using: .utf8) ?? Data()
        self.init(raw: data)
    }
    public convenience init<T: Encodable>(encodable: T) throws {
        let data = try JSONEncoder().encode(encodable)
        self.init(raw: data)
    }
    public func encode() throws -> Data {
        headers["date"] = "\(Date())"
        headers["content-length"] = "\(contentLength)"
        let content = (["\(version) \(code)"] + headers.map { "\($0.key): \($0.value)" })
            .joined(separator: "\r\n") + "\r\n\r\n"
        guard let payload = content.data(using: .utf8) else {
            throw NSError(domain: "invalid payload encoding", code: 0)
        }
        return payload + body
    }
}

public struct HttpRequest {
    public enum Method: String {
        case GET
        case POST
        case HEAD
    }
    public let uri: URI
    public let method: Method
    public let version: String
    public let headers: [String: String]
    public let body: Data
    public static var contentLengthLimitation = 1048576
    public init?(request: Data) throws {
        let headData: Data
        if let separator = request.firstRange(of: "\r\n\r\n".data(using: .utf8) ?? Data()) {
            headData = request[..<separator.lowerBound]
            body = request[separator.upperBound...]
        } else {
            headData = request
            body = Data()
        }
        let head = String(data: headData, encoding: .utf8) ?? ""
        var lines = head.split(separator: "\r\n").map { String($0).trimmed }
        let uriPattern = try NSRegularExpression(pattern: "^(GET|POST|HEAD) (.*) HTTP/([0-9.]+)$", options: .caseInsensitive)
        let headerPattern = try NSRegularExpression(pattern: "^([a-zA-Z\\-]+):\\s(.*)$")
        guard !lines.isEmpty else {
            throw NSError(domain: "Bad Request", code: 400)
        }
        let top = lines.removeFirst()
        guard let uriMatch = uriPattern.firstMatch(in: top, range: top.range) else {
            throw NSError(domain: "Bad Request", code: 400)
        }
        let headString = head as NSString
        let methodRange = uriMatch.range(at: 1)
        method = Method(rawValue: headString.substring(with: methodRange).uppercased()) ?? .GET
        let uriRange = uriMatch.range(at: 2)
        let uriString = headString.substring(with: uriRange)
        let versionRange = uriMatch.range(at: 3)
        version = headString.substring(with: versionRange)
        uri = URI(uri: uriString)
        let keyValues = lines.compactMap { line -> (String, String)? in
            guard let expressionMatch = headerPattern.firstMatch(in: line, range: line.range) else {
                return nil
            }
            let keyRange = expressionMatch.range(at: 1)
            let valueRange = expressionMatch.range(at: 2)
            let expression = line as NSString
            let key = expression.substring(with: keyRange)
            let value = expression.substring(with: valueRange)
            return (key, value)
        }
        headers = Dictionary(uniqueKeysWithValues: keyValues)
        if let textContentLength = headers["Content-Length"], let contentLength = Int(textContentLength) {
            if contentLength > Self.contentLengthLimitation {
                throw NSError(domain: "Bad Request (oversized)", code: 400, userInfo: ["Content-Length": contentLength, "Content-Length-Limitation": Self.contentLengthLimitation])
            }
            let size = body.count
            guard size >= contentLength else {
                return nil
            }
        }
    }
    public var content: String? {
        return String(data: body, encoding: .utf8)
    }
}

public extension HttpRequest {
    var files: [HttpPostFile] {
        guard let contentTypePattern = try? NSRegularExpression(pattern: "^multipart/form-data; boundary=(.*)$"),
              let contentType = headers["Content-Type"],
              let boundaryMatch = contentTypePattern.firstMatch(in: contentType, range: contentType.range) else {
            return []
        }
        let boundaryRange = boundaryMatch.range(at: 1)
        let boundaryText = "--" + (contentType as NSString).substring(with: boundaryRange)
        guard let boundary = boundaryText.data(using: .utf8) else {
            return []
        }
        guard body.count > 4 else {
            return []
        }
        var multiparts = body
        var results: [HttpPostFile] = []
        while !multiparts.isEmpty {
            guard let dataRange = multiparts.firstRange(of: boundary) else {
                break
            }
            let part = multiparts[..<dataRange.lowerBound]
            if let file = HttpPostFile(multipartBlock: part) {
                results.append(file)
            }
            multiparts = multiparts[dataRange.upperBound...]
        }
        return results
    }
}

public extension HttpRequest {
    /// post fields, if applicable
    /// *note*: field name can be duplicated to construct an array, so that's the reason we are using an array of tuple instead of a dictionary
    var postFieldArray: [(String, String)] {
        guard let postBodyString = String(data: body, encoding: .utf8) else {
            return []
        }
        return postBodyString.split(separator: "&").compactMap { exp -> (String, String)? in
            print(String(exp))
            let expression = String(exp).urlDecoded
            guard let equal = expression.firstIndex(of: Character("=")) else {
                return nil
            }
            let key = expression[..<equal]
            let value = expression[expression.index(after: equal)...]
            if key.isEmpty || value.isEmpty {
                return nil
            }
            return (String(key).urlDecoded, String(value).urlDecoded)
        }
    }
    /// post fields, if applicable
    /// *note*: in case of field name that duplicated for value array, use `postFieldArray` instead.
    var postFields: [String: String] {
        return Dictionary(uniqueKeysWithValues: postFieldArray)
    }
}

public struct HttpPostFile {
    let attributes: [String: String]
    let content: Data
    public init?(multipartBlock: Data) {
        guard multipartBlock.count > 4 else { return nil }
        let block = multipartBlock.dropFirst(2).dropLast(2)
        guard let lineBreaks = "\r\n\r\n".data(using: .utf8),
              let location = block.firstRange(of: lineBreaks) else {
            return nil
        }
        let headText = (String(data: block[..<location.lowerBound], encoding: .utf8) ?? "")
            .replacingOccurrences(of: "\r\n", with: ";")
            .replacingOccurrences(of: ": ", with: "=")
        content = block[location.upperBound...]
        print(content.count)
        let headers: [(String, String)] = headText
            .split(separator: ";")
            .compactMap { expression -> (String, String)? in
                let exp = String(expression).split(separator: "=")
                guard exp.count == 2, let key = exp.first, let value = exp.last else {
                    return nil
                }
                return (String(key).trimmed, String(value).trimmed)
            }
        guard !headers.isEmpty else {
            return nil
        }
        attributes = Dictionary(uniqueKeysWithValues: headers)
    }
}

public struct URI {
    public let raw: String
    public let path: [String]
    /// in case of parameters with duplicated keys to implement value array, use parameterArray instead.
    public let parameterArray: [(String, String)]
    /// will remove duplicated keys
    public let parameters: [String: String]
    public init(uri: String) {
        raw = uri
        let resources = uri.split(separator: "?").map { String($0) }
        let api: String
        if let _api = resources.first {
            api = _api
            if resources.count > 1, let _params = resources.last {
                parameterArray = _params.split(separator: "&").compactMap { expression -> (String, String)? in
                    guard let equal = expression.firstIndex(of: "=") else {
                        return nil
                    }
                    let key = expression[expression.startIndex..<equal]
                    let value = expression[expression.index(equal, offsetBy: 1)..<expression.endIndex]
                    return (String(key).urlDecoded, String(value).urlDecoded)
                }
                parameters = Dictionary(uniqueKeysWithValues: parameterArray)
            } else {
                parameterArray = []
                parameters = [:]
            }
        } else {
            api = uri
            parameterArray = []
            parameters = [:]
        }
        path = api.split(separator: "/").map { String($0) }
    }
}

public extension String {
    var trimmed: String {
        let blanks = CharacterSet(charactersIn: " \t\r\n")
        return trimmingCharacters(in: blanks)
    }
    var range: NSRange {
        return NSRange(location: 0, length: count)
    }
    var urlEncoded: String {
        return addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? self
    }
    var urlDecoded: String {
        return removingPercentEncoding ?? self
    }

    func sniffMIME() -> String {
        let defaultMime = "application/octet-stream"
        guard let suffixSubstring = split(separator: ".").last else {
            return defaultMime
        }
        let suffix = String(suffixSubstring).lowercased()
        let mime: String
        switch suffix {
        case "aac": // AAC audio
            mime = "audio/aac"
        case "abw": // AbiWord document
            mime = "application/x-abiword"
        case "arc": // Archive document (multiple files embedded)
            mime = "application/x-freearc"
        case "avif": // AVIF image
            mime = "image/avif"
        case "avi": // AVI: Audio Video Interleave
            mime = "video/x-msvideo"
        case "azw": // Amazon Kindle eBook format
            mime = "application/vnd.amazon.ebook"
        case "bin": // Any kind of binary data
            mime = "application/octet-stream"
        case "bmp": // Windows OS/2 Bitmap Graphics
            mime = "image/bmp"
        case "bz": // BZip archive
            mime = "application/x-bzip"
        case "bz2": // BZip2 archive
            mime = "application/x-bzip2"
        case "cda": // CD audio
            mime = "application/x-cdf"
        case "csh": // C-Shell script
            mime = "application/x-csh"
        case "css": // Cascading Style Sheets (CSS)
            mime = "text/css"
        case "csv": // Comma-separated values (CSV)
            mime = "text/csv"
        case "doc": // Microsoft Word
            mime = "application/msword"
        case "docx": // Microsoft Word (OpenXML)
            mime = "application/vnd.openxmlformats"
        case "eot": // MS Embedded OpenType fonts
            mime = "application/vnd.ms-fontobject"
        case "epub": // Electronic publication (EPUB)
            mime = "application/epub+zip"
        case "gz": // GZip Compressed Archive
            mime = "application/gzip"
        case "gif": // Graphics Interchange Format (GIF)
            mime = "image/gif"
        case "htm", "html": // HyperText Markup Language (HTML)
            mime = "text/html"
        case "ico": // Icon format
            mime = "image/vnd.microsoft.icon"
        case "ics": // iCalendar format
            mime = "text/calendar"
        case "jar": // Java Archive (JAR)
            mime = "application/java-archive"
        case "jpeg, .jpg": // JPEG images
            mime = "image/jpeg"
        case "js": // JavaScript
            mime = "text/javascript"
        case "json": // JSON format
            mime = "application/json"
        case "jsonld": // JSON-LD format
            mime = "application/ld+json"
        case "mid", "midi": // Musical Instrument Digital Interface (MIDI)
            mime = "audio/midi, audio/x-midi"
        case "mjs": // JavaScript module
            mime = "text/javascript"
        case "mp3": // MP3 audio
            mime = "audio/mpeg"
        case "mp4": // MP4 video
            mime = "video/mp4"
        case "mpeg": // MPEG Video
            mime = "video/mpeg"
        case "mpkg": // Apple Installer Package
            mime = "application/vnd.apple.installer+xml"
        case "odp": // OpenDocument presentation document
            mime = "application/vnd.oasis.opendocument.presentation"
        case "ods": // OpenDocument spreadsheet document
            mime = "application/vnd.oasis.opendocument.spreadsheet"
        case "odt": // OpenDocument text document
            mime = "application/vnd.oasis.opendocument.text"
        case "oga": // OGG audio
            mime = "audio/ogg"
        case "ogv": // OGG video
            mime = "video/ogg"
        case "ogx": // OGG
            mime = "application/ogg"
        case "opus": // Opus audio
            mime = "audio/opus"
        case "otf": // OpenType font
            mime = "font/otf"
        case "png": // Portable Network Graphics
            mime = "image/png"
        case "pdf": // Adobe Portable Document Format (PDF)
            mime = "application/pdf"
        case "php": // Hypertext Preprocessor (Personal Home Page)
            mime = "application/x-httpd-php"
        case "ppt": // Microsoft PowerPoint
            mime = "application/vnd.ms-powerpoint"
        case "pptx": // Microsoft PowerPoint (OpenXML)
            mime = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "rar": // RAR archive
            mime = "application/vnd.rar"
        case "rtf": // Rich Text Format (RTF)
            mime = "application/rtf"
        case "sh": // Bourne shell script
            mime = "application/x-sh"
        case "svg": // Scalable Vector Graphics (SVG)
            mime = "image/svg+xml"
        case "tar": // Tape Archive (TAR)
            mime = "application/x-tar"
        case "tif", "tiff": // Tagged Image File Format (TIFF)
            mime = "image/tiff"
        case "ts": // MPEG transport stream
            mime = "video/mp2t"
        case "ttf": // TrueType Font
            mime = "font/ttf"
        case "txt": // Text, (generally ASCII or ISO 8859-n)
            mime = "text/plain"
        case "vsd": // Microsoft Visio
            mime = "application/vnd.visio"
        case "wav": // Waveform Audio Format
            mime = "audio/wav"
        case "weba": // WEBM audio
            mime = "audio/webm"
        case "webm": // WEBM video
            mime = "video/webm"
        case "webp": // WEBP image
            mime = "image/webp"
        case "woff": // Web Open Font Format (WOFF)
            mime = "font/woff"
        case "woff2": // Web Open Font Format (WOFF)
            mime = "font/woff2"
        case "xhtml": // XHTML
            mime = "application/xhtml+xml"
        case "xls": // Microsoft Excel
            mime = "application/vnd.ms-excel"
        case "xlsx": // Microsoft Excel (OpenXML)
            mime = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "xml": // XML
            mime = "application/xml"
        case "xul": // XUL
            mime = "application/vnd.mozilla.xul+xml"
        case "zip": // ZIP archive
            mime = "application/zip"
        case "3gp": // 3GPP audio/video container
            mime = "video/3gpp"
        case "3g2": // 3GPP2 audio/video container
            mime = "video/3gpp2"
        case "7z": // 7-zip archive
            mime = "application/x-7z-compressed"
        default:
            mime = defaultMime
        }
        return mime
    }
}

public extension URL {
    func sniffMIME() -> String {
        return lastPathComponent.sniffMIME()
    }
}

public extension FileManager {
    func size(of path: String) throws -> Int {
        guard let file = fopen(path, "rb") else {
            throw NSError(domain: "File Not Found", code: 404, userInfo: ["path": path])
        }
        defer {
            fclose(file)
        }
        guard -1 != fseek(file, 0, SEEK_END) else {
            throw NSError(domain: "Unauthorized", code: 401, userInfo: ["path": path, "size": "unknown"])
        }
        return ftell(file)
    }
}
