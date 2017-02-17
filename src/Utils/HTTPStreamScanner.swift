import Foundation

class HTTPStreamScanner {
    enum ReadAction {
        case readHeader, readContent(Int), stop
    }
    
    enum Result {
        case header(HTTPHeader), content(Data)
    }
    
    enum HTTPStreamScannerError: Error {
        case contentIsTooLong, scannerIsStopped, unsupportedStreamType
    }
    
    var nextAction: ReadAction = .readHeader
    
    var remainContentLength: Int = 0
    
    // Remember all of the hosts we have scanned
    var hostAndPorts: [String: Int] = [String: Int]()
    
    var currentHeader: HTTPHeader!
    
    var isConnect: Bool = false
    
    func input(_ data: Data) throws -> Result {
        switch nextAction {
        case .readHeader:
            let header: HTTPHeader
            do {
                header = try HTTPHeader(headerData: data)
            } catch let error {
                nextAction = .stop
                throw error
            }
            
            if hostAndPorts[header.host+":"+String(header.port)] == nil {
                if header.isConnect {
                    isConnect = true
                    remainContentLength = -1
                } else {
                    isConnect = false
                    remainContentLength = header.contentLength
                }
            } else {
                isConnect = header.isConnect
                remainContentLength = header.contentLength
            }
            
            hostAndPorts[header.host+":"+String(header.port)] = 1
            
            currentHeader = header
            
            setNextAction()
            
            return .header(header)
        case .readContent:
            remainContentLength -= data.count
            if !isConnect && remainContentLength < 0 {
                nextAction = .stop
                throw HTTPStreamScannerError.contentIsTooLong
            }
            
            setNextAction()
            
            return .content(data)
        case .stop:
            throw HTTPStreamScannerError.scannerIsStopped
        }
    }
    
    fileprivate func setNextAction() {
        switch remainContentLength {
        case 0:
            nextAction = .readHeader
        case _ where remainContentLength < 0:
            nextAction = .readContent(-1)
        default:
            nextAction = .readContent(min(remainContentLength, Opt.MAXHTTPContentBlockLength))
        }
    }
}
