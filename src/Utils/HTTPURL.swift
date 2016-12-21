import Foundation

public class HTTPURL {
    public let scheme: String?
    public let host: String
    public let port: Int?
    //    public let path: String
    public let relativePath: String

    // swiftlint:disable:next force_try
    static let urlreg = try! NSRegularExpression(pattern: "^(?:(https?):\\/\\/)?([\\w\\.]+)(?::(\\d+))?(?:\\/(.*))?$", options: NSRegularExpression.Options.caseInsensitive)

    init?(string url: String) {
        let nsurl = url as NSString

        guard let result = HTTPURL.urlreg.firstMatch(in: url, range: NSRange(location: 0, length: nsurl.length)) else {
            return nil
        }

        guard result.numberOfRanges == 5 else {
            return nil
        }

        guard result.rangeAt(0).location != NSNotFound else {
            return nil
        }

        var range = result.rangeAt(1)
        if range.location != NSNotFound {
            scheme = nsurl.substring(with: range)
        } else {
            scheme = nil
        }

        range = result.rangeAt(2)
        guard range.location != NSNotFound else {
            return nil
        }
        host = nsurl.substring(with: range)

        range = result.rangeAt(3)
        if range.location != NSNotFound {
            port = Int(nsurl.substring(with: range))
        } else {
            port = nil
        }

        range = result.rangeAt(4)
        if range.location != NSNotFound {
            relativePath = nsurl.substring(with: range)
        } else {
            relativePath = ""
        }

    }
}
