import Foundation

class AuthenticationAdapterFactory : ServerAdapterFactory {
    let auth :Authentication?
    
    init(host: String, port: Int, auth: Authentication?) {
        self.auth = auth
        super.init(host: host, port: port)
    }
}