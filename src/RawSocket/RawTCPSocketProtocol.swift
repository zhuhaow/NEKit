import Foundation

/// The raw socket protocol which represents a TCP socket.
///
/// Any concrete implementation does not need to be thread-safe.
///
/// - warning: It is expected that the instance is accessed on the specific queue only.
public protocol RawTCPSocketProtocol : class {
    /// The `RawTCPSocketDelegate` instance.
    var delegate: RawTCPSocketDelegate? { get set }

    /// If the socket is connected.
    var isConnected: Bool { get }

    /// The source address.
    var sourceIPAddress: IPAddress? { get }

    /// The source port.
    var sourcePort: Port? { get }

    /// The destination address.
    var destinationIPAddress: IPAddress? { get }

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
    func connectTo(host: String, port: Int, enableTLS: Bool, tlsSettings: [AnyHashable: Any]?) throws

    /**
     Disconnect the socket.

     The socket should disconnect elegantly after any queued writing data are successfully sent.

     - note: Usually, any concrete implementation should wait until any pending writing data are finished then call `forceDisconnect()`.
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
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    func write(data: Data)

    /**
     Read data from the socket.

     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readData()

    /**
     Read specific length of data from the socket.

     - parameter length: The length of the data to read.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataTo(length: Int)

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataTo(data: Data)

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter maxLength: The max length of data to scan for the pattern.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataTo(data: Data, maxLength: Int)
}

/// The delegate protocol to handle the events from a raw TCP socket.
public protocol RawTCPSocketDelegate: class {
    /**
     The socket did disconnect.

     This should only be called once in the entire lifetime of a socket. After this is called, the delegate will not receive any other events from that socket and the socket should be released.

     - parameter socket: The socket which did disconnect.
     */
    func didDisconnectWith(socket: RawTCPSocketProtocol)

    /**
     The socket did read some data.

     - parameter data:    The data read from the socket.
     - parameter from:    The socket where the data is read from.
     */
    func didRead(data: Data, from: RawTCPSocketProtocol)

    /**
     The socket did send some data.

     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter by:      The socket where the data is sent out.
     */
    func didWrite(data: Data?, by: RawTCPSocketProtocol)

    /**
     The socket did connect to remote.

     - parameter socket: The connected socket.
     */
    func didConnectWith(socket: RawTCPSocketProtocol)
}
