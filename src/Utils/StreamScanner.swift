import Foundation

class StreamScanner {
    var receivedData: NSMutableData = NSMutableData()
    let pattern: NSData
    let maximumLength: Int
    var finished = false

    var currentLength: Int {
        return receivedData.length
    }

    init(pattern: NSData, maximumLength: Int) {
        self.pattern = pattern
        self.maximumLength = maximumLength
    }

    // I know this is not the most effcient algorithm if there is a large number of NSDatas, but since we only need to find the CRLF in http header (as of now), and it should be ready in the first readData call, there is no need to implement a complicate algorithm which is very likely to be slower in such case.
    func addAndScan(data: NSData) -> (NSData?, NSData)? {
        guard finished == false else {
            return nil
        }

        receivedData.appendData(data)
        let startind = max(0, receivedData.length - pattern.length - data.length)
        let range = receivedData.rangeOfData(pattern, options: .Backwards, range: NSRange(location: startind, length: receivedData.length - startind))

        if range.location == NSNotFound {
            if receivedData.length > maximumLength {
                finished = true
                return (nil, receivedData)
            } else {
                return nil
            }
        } else {
            finished = true
            let foundEndIndex = range.location + range.length
            return (receivedData.subdataWithRange(NSRange(location: 0, length: foundEndIndex)), receivedData.subdataWithRange(NSRange(location: foundEndIndex, length: receivedData.length - foundEndIndex)))
        }
    }
}
