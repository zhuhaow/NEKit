import Foundation

class HTTPStreamScanner {
    enum ReadAction {
        case ReadHeader, ReadContent(Int), Stop
    }

    var nextAction: ReadAction = .ReadHeader

    var remainContentLength: Int = 0

    var currentHeader: HTTPHeader!

    var isConnect: Bool = false

    func input(data: NSData) -> (HTTPHeader?, NSData?) {
        switch nextAction {
        case .ReadHeader:
            guard let header = HTTPHeader(headerData: data) else {
                nextAction = .Stop
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
        case .ReadContent:
            remainContentLength -= data.length
            if !isConnect && remainContentLength < 0 {
                nextAction = .Stop
                return (nil, nil)
            }

            setNextAction()

            return (nil, data)
        case .Stop:
            return (nil, nil)
        }
    }

    private func setNextAction() {
        switch remainContentLength {
        case 0:
            nextAction = .ReadHeader
        case -1:
            nextAction = .ReadContent(-1)
        default:
            nextAction = .ReadContent(min(remainContentLength, Opt.MAXHTTPContentBlockLength))
        }
    }
}
