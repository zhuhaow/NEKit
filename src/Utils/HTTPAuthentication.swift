import Foundation

/**
 *  The helper wrapping up an HTTP basic authentication credential.
 */
public struct HTTPAuthentication {
    /// The username of the credential.
    public let username: String

    /// The password of the credential.
    public let password: String

    /**
     Initailize the credential with username and password.

     - parameter username: The username of the credential.
     - parameter password: The password of the credential.

     - returns: The credential.
     */
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    /**
     Return the base64 encoded string of the credential.

     - returns: The credential encoded with `"\(username):\(password)"`
     */
    public func encoding() -> String? {
        let auth = "\(username):\(password)"
        return auth.data(using: String.Encoding.utf8)?.base64EncodedString(options: NSData.Base64EncodingOptions.endLineWithLineFeed)
    }

    /**
     Return the full header field content for `Authorization` of an HTTP basic authentication.

     - returns: The encoded authentication string.
     */
    public func authString() -> String {
        return "Basic \(encoding()!)"
    }
}
