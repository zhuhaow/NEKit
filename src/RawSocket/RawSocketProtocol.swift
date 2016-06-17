import Foundation
import CocoaLumberjackSwift

protocol RawSocketProtocol : class {
    /// Should be set before any method call.
    weak var delegate: RawSocketDelegate? { get set }
    /// Every delegate method should be called on this dispatch queue.
    var delegateQueue: dispatch_queue_t! { get set }
    var connected: Bool { get }
    var sourceIPAddress: IPv4Address? { get }
    var sourcePort: Port? { get }
    var destinationIPAddress: IPv4Address? { get }
    var destinationPort: Port? { get }

    func connectTo(host: String, port: Int, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?)
    func disconnect()
    func forceDisconnect()

    /**
     Write data to socket.

     - parameter data: data to write
     - parameter tag:  the tag identifying the data in the callback delegate method
     */
    func writeData(data: NSData, withTag: Int)

//    func closeWrite()

    /**
     Read data from the socket

     - parameter tag: the tag identifying the data in callback delegate method.
     - note: This should only be called after the delegate method `didReadData` is called for previous readData call.
     */
    func readDataWithTag(tag: Int)
    func readDataToLength(length: Int, withTag tag: Int)
    func readDataToData(data: NSData, withTag tag: Int)
}

protocol RawSocketDelegate: class {
    func didDisconnect(socket: RawSocketProtocol)
    func didReadData(data: NSData, withTag: Int, from: RawSocketProtocol)
    func didWriteData(data: NSData?, withTag: Int, from: RawSocketProtocol)
    func didConnect(socket: RawSocketProtocol)
}
