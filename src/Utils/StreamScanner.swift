import Foundation

open class StreamScanner {
    var receivedData: NSMutableData = NSMutableData()
    let pattern: Data
    let maximumLength: Int
    var finished = false

    var currentLength: Int {
        return receivedData.length
    }

    public init(pattern: Data, maximumLength: Int) {
        self.pattern = pattern
        self.maximumLength = maximumLength
    }

    // I know this is not the most effcient algorithm if there is a large number of NSDatas, but since we only need to find the CRLF in http header (as of now), and it should be ready in the first readData call, there is no need to implement a complicate algorithm which is very likely to be slower in such case.
    open func addAndScan(_ data: Data) -> (Data?, Data)? {
        guard finished == false else {
            return nil
        }

        receivedData.append(data)
        let startind = max(0, receivedData.length - pattern.count - data.count)
        let range = receivedData.range(of: pattern, options: .backwards, in: NSRange(location: startind, length: receivedData.length - startind))

        if range.location == NSNotFound {
            if receivedData.length > maximumLength {
                finished = true
                return (nil, receivedData as Data)
            } else {
                return nil
            }
        } else {
            finished = true
            let foundEndIndex = range.location + range.length
            return (receivedData.subdata(with: NSRange(location: 0, length: foundEndIndex)), receivedData.subdata(with: NSRange(location: foundEndIndex, length: receivedData.length - foundEndIndex)))
        }
    }
}
