import Foundation
import tun2socks

class TUNTCPSocket: RawSocketProtocol, TSTCPSocketDelegate {
    let tsSocket: TSTCPSocket
    var readTag: Int?
    var pendingReadData: NSMutableData = NSMutableData()
    var writeTag: Int!
    var remainWriteLength: Int = 0
    var closeAfterWriting = false

    var sourceIPAddress: IPv4Address? {
        return IPv4Address(fromInAddr: tsSocket.sourceAddress.s_addr)
    }

    var sourcePort: Int? {
        return Int(tsSocket.sourcePort)
    }

    var destinationIPAddress: IPv4Address? {
        return IPv4Address(fromInAddr: tsSocket.destinationAddress.s_addr)
    }

    var destinationPort: Int? {
        return Int(tsSocket.destinationPort)
    }

    init(socket: TSTCPSocket) {
        tsSocket = socket
        tsSocket.delegate = self
    }

    private func delegateCall(block: ()->()) {
        dispatch_async(delegateQueue, block)
    }

    private func checkReadData() {
        if pendingReadData.length > 0 {
            delegateCall {
                // the didReadData might change the readTag
                guard let tag = self.readTag else {
                    return
                }
                self.readTag = nil
                self.delegate?.didReadData(self.pendingReadData, withTag: tag, from: self)
                self.pendingReadData = NSMutableData()
            }
        }
    }

    private func checkStatus() {
        if closeAfterWriting && remainWriteLength == 0 {
            forceDisconnect()
        }
    }

    // MARK: RawSocketProtocol implemention
    weak var delegate: RawSocketDelegate?

    var delegateQueue: dispatch_queue_t!
    var connected: Bool {
        return tsSocket.connected
    }

    // TUNTCPSocket can not connect to anything actively.
    func connectTo(host: String, port: Int, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) {}

    func disconnect() {
        delegateCall {
            self.closeAfterWriting = true
            self.checkStatus()
        }
    }

    func forceDisconnect() {
        delegateCall {
            self.tsSocket.close()
        }
    }

    func writeData(data: NSData, withTag tag: Int) {
        delegateCall {
            self.writeTag = tag
            self.remainWriteLength = data.length
            self.tsSocket.writeData(data)
        }
    }

    /**
     Read data from the socket

     - parameter tag: the tag identifying the data in callback delegate method.
     - note: This should only be called after the delegate method `didReadData` is called for previous readData call.
     */
    func readDataWithTag(tag: Int) {
        delegateCall {
            self.readTag = tag
            self.checkReadData()
        }
    }

    func readDataToLength(length: Int, withTag tag: Int) {}
    func readDataToData(data: NSData, withTag tag: Int) {}

    // MARK: TSTCPSocketDelegate implemention
    // The local stop sending anything, just ignore it.
    func localDidClose(socket: TSTCPSocket) {}

    func socketDidReset(socket: TSTCPSocket) {
        socketDidClose(socket)
    }

    func socketDidAbort(socket: TSTCPSocket) {
        socketDidClose(socket)
    }

    func socketDidClose(socket: TSTCPSocket) {
        delegateCall {
            self.delegate?.didDisconnect(self)
        }
    }

    func didReadData(data: NSData, from: TSTCPSocket) {
        delegateCall {
            self.pendingReadData.appendData(data)
            self.checkReadData()
        }
    }

    func didWriteData(length: Int, from: TSTCPSocket) {
        delegateCall {
            self.remainWriteLength -= length
            if self.remainWriteLength <= 0 {

                self.delegate?.didWriteData(nil, withTag: self.writeTag, from: self)
                self.checkStatus()
            }
        }
    }
}
