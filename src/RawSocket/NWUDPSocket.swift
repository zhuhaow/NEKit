import Foundation
import NetworkExtension
import CocoaLumberjackSwift

/// The delegate protocol of `NWUDPSocket`.
public protocol NWUDPSocketDelegate: class {
    /**
     Socket did receive data from remote.

     - parameter data: The data.
     - parameter from: The socket the data is read from.
     */
    func didReceiveData(_ data: Data, from: NWUDPSocket)
}

/// The wrapper for NWUDPSession.
///
/// - note: This class is thread-safe.
open class NWUDPSocket {
    fileprivate let session: NWUDPSession
    fileprivate var pendingWriteData: [Data] = []
    fileprivate var writing = false
    fileprivate let queue: DispatchQueue = DispatchQueue(label: "NWUDPSocket.queue", attributes: [])

    /// The delegate instance.
    open weak var delegate: NWUDPSocketDelegate?

    /// The time when the last activity happens.
    ///
    /// Since UDP do not have a "close" semantic, this can be an indicator of timeout.
    open var lastActive: Date = Date()

    /**
     Create a new UDP socket connecting to remote.

     - parameter host: The host.
     - parameter port: The port.
     */
    init?(host: String, port: Int) {
        guard let udpsession = RawSocketFactory.TunnelProvider?.createUDPSession(to: NWHostEndpoint(hostname: host, port: "\(port)"), from: nil) else {
            return nil
        }

        session = udpsession

        session.setReadHandler({ [ weak self ] dataArray, error in
            guard let sSelf = self else {
                return
            }

            sSelf.updateActivityTimer()

            guard error == nil, let dataArray = dataArray else {
                DDLogError("Error when reading from remote server. \(error?.localizedDescription ?? "Connection reset")")
                return
            }

            for data in dataArray {
                sSelf.delegate?.didReceiveData(data, from: sSelf)
            }
            }, maxDatagrams: 32)
    }

    /**
     Send data to remote.

     - parameter data: The data to send.
     */
    func writeData(_ data: Data) {
        queue.async {
            self.pendingWriteData.append(data)
            self.checkWrite()
        }
    }

    func disconnect() {
        queue.async {
            self.session.cancel()
        }
    }

    fileprivate func checkWrite() {
        queue.async {
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
            self.pendingWriteData.removeAll(keepingCapacity: true)
        }
    }

    fileprivate func updateActivityTimer() {
        lastActive = Date()
    }
}
