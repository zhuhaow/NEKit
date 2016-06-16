import Foundation
import NetworkExtension
import CocoaLumberjackSwift

protocol NWUDPSocketDelegate: class {
    func didReceiveData(data: NSData, from: NWUDPSocket)
}

class NWUDPSocket {
    let session: NWUDPSession
    weak var delegate: NWUDPSocketDelegate?
    var queue: dispatch_queue_t!
    var pendingWriteData: [NSData] = []
    var writing = false

    init(host: String, port: Int) {
        session = NetworkInterface.TunnelProvider.createUDPSessionToEndpoint(NWHostEndpoint(hostname: host, port: "\(port)"), fromEndpoint: nil)
        session.setReadHandler({ [ unowned self ] dataArray, error in
                guard error == nil else {
                    DDLogError("Error when reading from remote DNS server. \(error)")
                    return
                }

                dispatch_async(self.queue) {
                    for data in dataArray! {
                        self.delegate?.didReceiveData(data, from: self)
                    }
                }
            }, maxDatagrams: 32)
    }

    func writeData(data: NSData) {
        dispatch_async(queue) {
            self.pendingWriteData.append(data)
            self.checkWrite()
        }
    }

    private func checkWrite() {
        dispatch_async(queue) {
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

}
