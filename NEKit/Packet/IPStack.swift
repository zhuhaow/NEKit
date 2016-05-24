import Foundation
import tun2socks

class IPStack {
    static func start() {
        TUNIPStack.stack.startProcessing()
    }
}
