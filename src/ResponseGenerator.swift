import Foundation

open class ResponseGenerator {
    public let session: ConnectSession
    
    public init(withSession session: ConnectSession) {
        self.session = session
    }
    
    open func generateResponse() -> Data {
        return Data()
    }
}
