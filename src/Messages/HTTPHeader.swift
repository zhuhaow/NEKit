import Foundation

public class HTTPHeader {
    public var HTTPVersion: String
    public var method: String
    public var isConnect: Bool = false
    public var path: String
    public var pathURL: NSURL
    public var host: String
    public var port: Int
    // just assume that `Content-Length` is given as of now.
    // Chunk is not supported yet.
    public var contentLength: Int = 0
    public var headers: [(String, String)] = []
    public var rawHeader: NSData?
    
    public init?(headerString: String) {
        let lines = headerString.componentsSeparatedByString("\r\n")
        guard lines.count >= 3 else {
            return nil
        }
        
        let request = lines[0].componentsSeparatedByString(" ")
        guard request.count == 3 else {
            return nil
        }
        
        method = request[0]
        path = request[1]
        HTTPVersion = request[2]
        
        guard let _url = NSURL(string: path) else {
            return nil
        }
        pathURL = _url
        
        for line in lines[1..<lines.count-2] {
            let header = line.characters.split(":", maxSplit: 1, allowEmptySlices: false)
            guard header.count == 2 else {
                return nil
            }
            headers.append((String(header[0]).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()), String(header[1]).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())))
        }
        
        if method.uppercaseString == "CONNECT" {
            isConnect = true
            
            let urlInfo = path.componentsSeparatedByString(":")
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
            if pathURL.host != nil {
                host = pathURL.host!
                port = pathURL.port?.integerValue ?? 80
            } else {
                var url: String = ""
                for (key, value) in headers {
                    if "Host".caseInsensitiveCompare(key) == .OrderedSame {
                        url = value
                        break
                    }
                }
                guard url != "" else {
                    return nil
                }
                
                let urlInfo = url.componentsSeparatedByString(":")
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
                if "Content-Length".caseInsensitiveCompare(key) == .OrderedSame {
                    guard let contentLength = Int(value) else {
                        return nil
                    }
                    self.contentLength = contentLength
                    break
                }
            }
        }
    }
    
    public convenience init?(headerData: NSData) {
        guard let headerString = NSString(data: headerData, encoding: NSUTF8StringEncoding) as? String else {
            return nil
        }
        
        self.init(headerString: headerString)
        rawHeader = headerData
    }
    
    public subscript(index: String) -> String? {
        get {
            for (key, value) in headers {
                if index.caseInsensitiveCompare(key) == .OrderedSame {
                    return value
                }
            }
            return nil
        }
    }
    
    
    public func toData() -> NSData {
        return toString().dataUsingEncoding(NSUTF8StringEncoding)!
    }
    
    public func toString() -> String {
        var strRep = "\(method) \(path) \(HTTPVersion)\r\n"
        for (key, value) in headers {
            strRep += "\(key): \(value)\r\n"
        }
        strRep += "\r\n"
        return strRep
    }
    
    public func addHeader(key: String, value: String) {
        headers.append(key, value)
    }
    
    public func rewriteToRelativePath() {
        if path[path.startIndex] != "/" {
            guard let rewrotePath = URL.matchRelativePath(path) else {
                return
            }
            path = rewrotePath
        }
    }
    
    public func removeHeader(key: String) -> String? {
        for i in 0..<headers.count {
            if headers[i].0.caseInsensitiveCompare(key) == .OrderedSame {
                let (_, value) = headers.removeAtIndex(i)
                return value
            }
        }
        return nil
    }
    
    public func removeProxyHeader() {
        let ProxyHeader = ["Proxy-Authenticate", "Proxy-Authorization", "Proxy-Connection"]
        for header in ProxyHeader {
            removeHeader(header)
        }
    }
    
    struct URL {
        // swiftlint:disable:next force_try
        static let relativePathRegex = try! NSRegularExpression(pattern: "http.?:\\/\\/.*?(\\/.*)", options: NSRegularExpressionOptions.CaseInsensitive)
        
        static func matchRelativePath(url: String) -> String? {
            if let result = relativePathRegex.firstMatchInString(url, options: NSMatchingOptions(), range: NSRange(location: 0, length: url.characters.count)) {
                
                return (url as NSString).substringWithRange(result.rangeAtIndex(1))
            } else {
                return nil
            }
        }
    }
}
