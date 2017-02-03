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
    
    var currentHeader: HTTPHeader!
    
    var isConnect: Bool = false
    
    func input(_ data: Data) throws -> Result {
        switch nextAction {
        case .readHeader:
            let header: HTTPHeader
            do {
                header = try HTTPHeader(headerData: data)
                // To temporarily solve a bug in firefox for mac
                if currentHeader != nil && header.host != currentHeader.host {
                    throw HTTPStreamScannerError.unsupportedStreamType
                }
            } catch let error {
                nextAction = .stop
                throw error
            }
            
            if currentHeader == nil {
                if header.isConnect {
                    isConnect = true
                    remainContentLength = -1
                } else {
                    isConnect = false
                    remainContentLength = header.contentLength
                }
            } else {
                remainContentLength = header.contentLength
            }
            
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
