import Foundation
import NetworkExtension
import CocoaLumberjackSwift

/// The delegate protocol of `NWUDPSocket`.
protocol NWUDPSocketDelegate: class {
    /**
     Socket did receive data from remote.

     - parameter data: The data.
     - parameter from: The socket the data is read from.
     */
    func didReceiveData(data: NSData, from: NWUDPSocket)
}

/// The wrapper for NWUDPSession.
///
/// - note: This class is thread-safe.
public class NWUDPSocket {
    private let session: NWUDPSession
    private var pendingWriteData: [NSData] = []
    private var writing = false
    private let queue: dispatch_queue_t = dispatch_queue_create("NWUDPSocket.queue", DISPATCH_QUEUE_SERIAL)

    /// The delegate instance.
    weak var delegate: NWUDPSocketDelegate?

    /// The time when the last activity happens.
    ///
    /// Since UDP do not have a "close" semantic, this can be an indicator of timeout.
    public var lastActive: NSDate = NSDate()

    /**
     Create a new UDP socket connecting to remote.

     - parameter host: The host.
     - parameter port: The port.
     */
    init?(host: String, port: Int) {
        guard let udpsession = RawSocketFactory.TunnelProvider?.createUDPSessionToEndpoint(NWHostEndpoint(hostname: host, port: "\(port)"), fromEndpoint: nil) else {
            return nil
        }

        session = udpsession

        session.setReadHandler({ [ weak self ] dataArray, error in
            guard let sSelf = self else {
                return
            }

            sSelf.updateActivityTimer()

            guard error == nil else {
                DDLogError("Error when reading from remote server. \(error)")
                return
            }

            for data in dataArray! {
                sSelf.delegate?.didReceiveData(data, from: sSelf)
            }
            }, maxDatagrams: 32)
    }

    /**
     Send data to remote.

     - parameter data: The data to send.
     */
    func writeData(data: NSData) {
        dispatch_async(queue) {
            self.pendingWriteData.append(data)
            self.checkWrite()
        }
    }

    func disconnect() {
        dispatch_async(queue) {
            self.session.cancel()
        }
    }

    private func checkWrite() {
        dispatch_async(queue) {
            self.updateActivityTimer()

            guard !self.writing else {
                return
            }

            guard self.pendingWriteData.count > 0 else {
                return
            }

            self.writing = true
            self.session.writeMultipleDatagrams(self.pendingWriteData) {_ in
                self.writing = false
                self.checkWrite()
            }
            self.pendingWriteData.removeAll(keepCapacity: true)
        }
    }

    private func updateActivityTimer() {
        lastActive = NSDate()
    }
}
