import Foundation
import CocoaAsyncSocket
import CocoaLumberjackSwift

/**
 *  This is the swift wrapper around GCDAsyncSocket.
 */
class GCDTCPSocket: NSObject, GCDAsyncSocketDelegate, RawSocketProtocol {
    let socket: GCDAsyncSocket
    var delegateQueue: dispatch_queue_t! = nil {
        didSet {
            socket.setDelegate(self, delegateQueue: delegateQueue)
        }
    }
    weak var delegate: RawSocketDelegate?

    private var enableTLS: Bool = false
    var connected: Bool {
        return !socket.isDisconnected
    }

    init(socket: GCDAsyncSocket? = nil) {
        if let socket = socket {
            self.socket = socket
        } else {
            self.socket = GCDAsyncSocket()
        }
        super.init()
    }

    // MARK: RawSocketProtocol implemention
    func connectTo(host: String, port: Int, enableTLS: Bool = false, tlsSettings: [NSObject : AnyObject]? = nil) {
        connectToHost(host, withPort: port)
        self.enableTLS = enableTLS
        if enableTLS {
            startTLS(tlsSettings)
        }
    }

    func disconnect() {
        // This method is only called when the socket on the other side is closed, which means reading on this side simply makes no use.
        // Further, this will significantly extend the waiting time before disconnecting.
        socket.disconnectAfterWriting()
    }

    func forceDisconnect() {
        socket.disconnect()
    }

    func writeData(data: NSData, withTag tag: Int) {
        writeData(data, withTimeout: -1, withTag: tag)
    }

    func readDataWithTag(tag: Int) {
        socket.readDataWithTimeout(-1, tag: tag)
    }

    func readDataToLength(length: Int, withTag tag: Int) {
        readDataToLength(length, withTimeout: -1, withTag: tag)
    }

    func readDataToData(data: NSData, withTag tag: Int) {
        readDataToData(data, withTimeout: -1, withTag: tag)
    }

    // MARK: other helper methods
    func writeData(data: NSData, withTimeout timeout: Double, withTag tag: Int) {
        socket.writeData(data, withTimeout: timeout, tag: tag)
    }

    func readDataToLength(length: Int, withTimeout timeout: Double, withTag tag: Int) {
        socket.readDataToLength(UInt(length), withTimeout: timeout, tag: tag)
    }

    func readDataToData(data: NSData, withTimeout timeout: Double, withTag tag: Int) {
        socket.readDataToData(data, withTimeout: timeout, tag: tag)
    }

    func connectToHost(host: String, withPort port: Int) {
        do {
            try socket.connectToHost(host, onPort: UInt16(port))
        } catch let error as NSError {
            DDLogError("\(error)")
        }
    }

    func startTLS(tlsSettings: [NSObject : AnyObject]!) {
        socket.startTLS(tlsSettings)
    }

    // MARK: delegate methods for GCDAsyncSocket
    func socket(sock: GCDAsyncSocket!, didWriteDataWithTag tag: Int) {
        delegate?.didWriteData(nil, withTag: tag, from: self)
    }

    func socket(sock: GCDAsyncSocket, didReadData data: NSData, withTag tag: Int) {
        delegate?.didReadData(data, withTag: tag, from: self)
    }

    func socketDidDisconnect(socket: GCDAsyncSocket!, withError err: NSError?) {
        delegate?.didDisconnect(self)
    }

    func socket(sock: GCDAsyncSocket!, didConnectToHost host: String!, port: UInt16) {
        if !enableTLS {
            delegate?.didConnect(self)
        }
    }

    func socketDidSecure(sock: GCDAsyncSocket!) {
        if enableTLS {
            delegate?.didConnect(self)
        }
    }

}
