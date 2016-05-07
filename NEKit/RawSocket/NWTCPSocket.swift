import Foundation
import NetworkExtension
import CocoaLumberjackSwift

class NWTCPSocket : NSObject, RawSocketProtocol {
    weak var delegate: RawSocketDelegate?
    
    var connection: NWTCPConnection!
    //    var lastError: NSError?
    //    private var dataQueue = Queue<NSData>()
    //    private var writingData = false
    var delegateQueue: dispatch_queue_t!
    
    var readPending = false
    var writePending = false
    var closeAfterReadingAndWriting = false
    
    var connected: Bool {
        return connection.state == .Connected
    }
    
    var cancelledSignaled = false
    
    // MARK: SocketProtocol implemention
    func connectTo(host: String, port: Int, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) {
        let endpoint = NWHostEndpoint(hostname: host, port: "\(port)")
        let tlsParameters = NWTLSParameters()
        if let tlsSettings = tlsSettings as? [String: AnyObject] {
            tlsParameters.setValuesForKeysWithDictionary(tlsSettings)
        }
        
        connection = NetworkInterface.TunnelProvider.createTCPConnectionToEndpoint(endpoint, enableTLS: enableTLS, TLSParameters: tlsParameters, delegate: nil)
        connection.addObserver(self, forKeyPath: "state", options: [.Initial, .New], context: nil)
    }
    
    func disconnect() {
        closeAfterReadingAndWriting = true
        checkStatus()
    }
    
    func forceDisconnect() {
        cancel()
    }
    
    func writeData(data: NSData, withTag tag: Int) {
        sendData(data, withTag: tag)
    }
    
    func readDataWithTag(tag: Int) {
        read(tag)
    }
    
    func readDataToLength(length: Int, withTag tag: Int) {
        read(tag, length: length)
    }
    
    func readDataToData(data: NSData, withTag tag: Int) {
        read(tag)
    }
    
    private func delegateCall(block: ()->()) {
        dispatch_async(delegateQueue, block)
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard keyPath == "state" else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            return
        }
        
        guard let change = change else {
            return
        }
        
        DDLogVerbose("\(change)")
        //        if let newValue = change[NSKeyValueChangeNewKey] as? NWTCPConnectionState {
        //
        //        }
        
        DDLogVerbose("SNWTunnel state changed to \(connection.state.rawValue).")
        
        switch connection.state {
        case .Connected:
            delegateCall() {
                self.delegate?.didConnect(self)
            }
        case .Disconnected:
            DDLogVerbose("Disconnected")
            cancel()
        case .Cancelled:
            DDLogVerbose("Cancelled")
            connection.removeObserver(self, forKeyPath: "state")
            if !cancelledSignaled {
                cancelledSignaled = true
                delegateCall() {
                    self.delegate?.didDisconnect(self)
                }
            }
        default:
            DDLogVerbose("SNWTunnel state is \(connection.state.rawValue).")
            break
        }
    }
    
    private func sendData(data: NSData, withTag tag: Int) {
        writePending = true
        self.connection.write(data) { error in
            self.writePending = false
            
            guard error == nil else {
                DDLogError("NWTCPSocket got an error when writing data: \(error)")
                self.disconnect()
                return
            }
            
            self.delegateCall() {
                self.delegate?.didWriteData(data, withTag: tag, from: self)
            }
            self.checkStatus()
        }
    }
    
    private func cancel() {
        connection.cancel()
    }
    
    private func read(tag: Int, length: Int = 0) {
        readPending = true
        connection.readMinimumLength(length, maximumLength: 30000) { data, error in
            self.readPending = false
            guard error == nil else {
                DDLogError("NWTCPSocket got an error when reading data: \(error)")
                self.disconnect()
                return
            }
            
            guard let data = data else {
                return
            }
            
            self.delegateCall() {
                self.delegate?.didReadData(data, withTag: tag, from: self)
            }
        }
    }
    
    private func checkStatus() {
        if closeAfterReadingAndWriting && !readPending && !writePending {
            cancel()
        }
    }
}