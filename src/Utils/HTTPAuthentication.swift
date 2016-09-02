import Foundation

public struct HTTPAuthentication {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public func encoding() -> String? {
        let auth = "\(username):\(password)"
        return auth.dataUsingEncoding(NSUTF8StringEncoding)?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.EncodingEndLineWithLineFeed)
    }

    public func authString() -> String {
        return "Basic \(encoding()!)"
    }
}
