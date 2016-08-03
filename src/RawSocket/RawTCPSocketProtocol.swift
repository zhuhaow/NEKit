import Foundation
import CocoaLumberjackSwift

/// The raw socket protocol which represents a TCP socket.
///
/// Any concrete implemention does not need to be thread-safe.
///
/// - warning: It is expected that the instance is accessed on the `queue` only.
protocol RawTCPSocketProtocol : class {
    /// The `RawTCPSocketDelegate` instance.
    weak var delegate: RawTCPSocketDelegate? { get set }

    /// Every delegate method should be called on this dispatch queue. And every method call and variable access will be called on this queue.
    var queue: dispatch_queue_t! { get set }

    /// If the socket is connected.
    var isConnected: Bool { get }

    /// The source address.
    var sourceIPAddress: IPv4Address? { get }

    /// The source port.
    var sourcePort: Port? { get }

    /// The destination address.
    var destinationIPAddress: IPv4Address? { get }

    /// The destination port.
    var destinationPort: Port? { get }

    /**
     Connect to remote host.

     - parameter host:        Remote host.
     - parameter port:        Remote port.
     - parameter enableTLS:   Should TLS be enabled.
     - parameter tlsSettings: The settings of TLS.

     - throws: The error occured when connecting to host.
     */
    func connectTo(host: String, port: Int, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) throws

    /**
     Disconnect the socket.

     The socket should disconnect elegantly after any queued writing data are successfully sent.

     - note: Usually, any concrete implemention should wait until any pending writing data are finished then call `forceDisconnect()`.
     */
    func disconnect()

    /**
     Disconnect the socket immediately.

     - note: The socket should disconnect as soon as possible.
     */
    func forceDisconnect()

    /**
     Send data to remote.

     - parameter data: Data to send.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    func writeData(data: NSData, withTag: Int)

    /**
     Read data from the socket.

     - parameter tag: The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataWithTag(tag: Int)

    /**
     Read specific length of data from the socket.

     - parameter length: The length of the data to read.
     - parameter tag:    The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataToLength(length: Int, withTag tag: Int)

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataToData(data: NSData, withTag tag: Int)

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - parameter maxLength: The max length of data to scan for the pattern.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataToData(data: NSData, withTag tag: Int, maxLength: Int)
}

/// The delegate protocol to handle the events from a raw TCP socket.
protocol RawTCPSocketDelegate: class {
    /**
     The socket did disconnect.

     This should only be called once in the entire lifetime of a socket. After this is called, the delegate will not receive any other events from that socket and the socket should be released.

     - parameter socket: The socket which did disconnect.
     */
    func didDisconnect(socket: RawTCPSocketProtocol)

    /**
     The socket did read some data.

     - parameter data:    The data read from the socket.
     - parameter withTag: The tag given when calling the `readData` method.
     - parameter from:    The socket where the data is read from.
     */
    func didReadData(data: NSData, withTag: Int, from: RawTCPSocketProtocol)

    /**
     The socket did send some data.

     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter withTag: The tag given when calling the `writeData` method.
     - parameter from:    The socket where the data is sent out.
     */
    func didWriteData(data: NSData?, withTag: Int, from: RawTCPSocketProtocol)

    /**
     The socket did connect to remote.

     - parameter socket: The connected socket.
     */
    func didConnect(socket: RawTCPSocketProtocol)
}
