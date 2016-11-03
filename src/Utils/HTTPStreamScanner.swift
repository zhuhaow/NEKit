import Foundation

class HTTPStreamScanner {
    enum ReadAction {
        case readHeader, readContent(Int), stop
    }

    var nextAction: ReadAction = .readHeader

    var remainContentLength: Int = 0

    var currentHeader: HTTPHeader!

    var isConnect: Bool = false

    func input(_ data: Data) -> (HTTPHeader?, Data?) {
        switch nextAction {
        case .readHeader:
            guard let header = HTTPHeader(headerData: data) else {
                nextAction = .stop
                return (nil, nil)
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

            return (header, nil)
        case .readContent:
            remainContentLength -= data.count
            if !isConnect && remainContentLength < 0 {
                nextAction = .stop
                return (nil, nil)
            }

            setNextAction()

            return (nil, data)
        case .stop:
            return (nil, nil)
        }
    }

    fileprivate func setNextAction() {
        switch remainContentLength {
        case 0:
            nextAction = .readHeader
        case -1:
            nextAction = .readContent(-1)
        default:
            nextAction = .readContent(min(remainContentLength, Opt.MAXHTTPContentBlockLength))
        }
    }
}
