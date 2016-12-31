import Foundation

open class ResponseGenerator {
    open let session: ConnectSession
    
    public init(withSession session: ConnectSession) {
        self.session = session
    }
    
    open func generateResponse() -> Data {
        return Data()
    }
}
