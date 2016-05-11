import Foundation

struct Authentication {
    let username: String
    let password: String

    func encoding() -> String? {
        let auth = "\(username):\(password)"
        return auth.dataUsingEncoding(NSUTF8StringEncoding)?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.EncodingEndLineWithLineFeed)
    }

    func authString() -> String {
        return "Basic \(encoding()!)"
    }
}
