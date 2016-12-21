import Foundation

open class HTTPHeader {
    open var HTTPVersion: String
    open var method: String
    open var isConnect: Bool = false
    open var path: String
    open var foundationURL: Foundation.URL?
    open var homemadeURL: HTTPURL?
    open var host: String
    open var port: Int
    // just assume that `Content-Length` is given as of now.
    // Chunk is not supported yet.
    open var contentLength: Int = 0
    open var headers: [(String, String)] = []
    open var rawHeader: Data?

    public init?(headerString: String) {
        let lines = headerString.components(separatedBy: "\r\n")
        guard lines.count >= 3 else {
            return nil
        }

        let request = lines[0].components(separatedBy: " ")
        guard request.count == 3 else {
            return nil
        }

        method = request[0]
        path = request[1]
        HTTPVersion = request[2]

        for line in lines[1..<lines.count-2] {
            let header = line.characters.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard header.count == 2 else {
                return nil
            }
            headers.append((String(header[0]).trimmingCharacters(in: CharacterSet.whitespaces), String(header[1]).trimmingCharacters(in: CharacterSet.whitespaces)))
        }

        if method.uppercased() == "CONNECT" {
            isConnect = true

            let urlInfo = path.components(separatedBy: ":")
            guard urlInfo.count == 2 else {
                return nil
            }
            host = urlInfo[0]
            guard let port = Int(urlInfo[1]) else {
                return nil
            }
            self.port = port

            self.contentLength = 0
        } else {
            var resolved = false

            host = ""
            port = 80

            if let _url = Foundation.URL(string: path) {
                foundationURL = _url
                if foundationURL!.host != nil {
                    host = foundationURL!.host!
                    port = foundationURL!.port ?? 80
                    resolved = true
                }
            } else {
                guard let _url = HTTPURL(string: path) else {
                    return nil
                }
                homemadeURL = _url
                if homemadeURL!.host != nil {
                    host = homemadeURL!.host!
                    port = homemadeURL!.port ?? 80
                    resolved = true
                }
            }

            if !resolved {
                var url: String = ""
                for (key, value) in headers {
                    if "Host".caseInsensitiveCompare(key) == .orderedSame {
                        url = value
                        break
                    }
                }
                guard url != "" else {
                    return nil
                }

                let urlInfo = url.components(separatedBy: ":")
                guard urlInfo.count <= 2 else {
                    return nil
                }
                if urlInfo.count == 2 {
                    host = urlInfo[0]
                    guard let port = Int(urlInfo[1]) else {
                        return nil
                    }
                    self.port = port
                } else {
                    host = urlInfo[0]
                    port = 80
                }
            }

            for (key, value) in headers {
                if "Content-Length".caseInsensitiveCompare(key) == .orderedSame {
                    guard let contentLength = Int(value) else {
                        return nil
                    }
                    self.contentLength = contentLength
                    break
                }
            }
        }
    }

    public convenience init?(headerData: Data) {
        guard let headerString = NSString(data: headerData, encoding: String.Encoding.utf8.rawValue) as? String else {
            return nil
        }

        self.init(headerString: headerString)
        rawHeader = headerData
    }

    open subscript(index: String) -> String? {
        get {
            for (key, value) in headers {
                if index.caseInsensitiveCompare(key) == .orderedSame {
                    return value
                }
            }
            return nil
        }
    }

    open func toData() -> Data {
        return toString().data(using: String.Encoding.utf8)!
    }

    open func toString() -> String {
        var strRep = "\(method) \(path) \(HTTPVersion)\r\n"
        for (key, value) in headers {
            strRep += "\(key): \(value)\r\n"
        }
        strRep += "\r\n"
        return strRep
    }

    open func addHeader(_ key: String, value: String) {
        headers.append(key, value)
    }

    open func rewriteToRelativePath() {
        if path[path.startIndex] != "/" {
            guard let rewrotePath = URL.matchRelativePath(path) else {
                return
            }
            path = rewrotePath
        }
    }

    open func removeHeader(_ key: String) -> String? {
        for i in 0..<headers.count {
            if headers[i].0.caseInsensitiveCompare(key) == .orderedSame {
                let (_, value) = headers.remove(at: i)
                return value
            }
        }
        return nil
    }

    open func removeProxyHeader() {
        let ProxyHeader = ["Proxy-Authenticate", "Proxy-Authorization", "Proxy-Connection"]
        for header in ProxyHeader {
            _ = removeHeader(header)
        }
    }

    struct URL {
        // swiftlint:disable:next force_try
        static let relativePathRegex = try! NSRegularExpression(pattern: "http.?:\\/\\/.*?(\\/.*)", options: NSRegularExpression.Options.caseInsensitive)

        static func matchRelativePath(_ url: String) -> String? {
            if let result = relativePathRegex.firstMatch(in: url, options: NSRegularExpression.MatchingOptions(), range: NSRange(location: 0, length: url.characters.count)) {

                return (url as NSString).substring(with: result.rangeAt(1))
            } else {
                return nil
            }
        }
    }
}
