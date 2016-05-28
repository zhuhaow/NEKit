import Foundation

protocol IPAddress: CustomStringConvertible {
    init(fromString: String)
    init(fromBytesInNetworkOrder: [UInt8])
    init(fromBytesInNetworkOrder: UnsafePointer<Void>)
}

class IPv4Address: IPAddress {
    var inaddr: UInt32

    init(fromInAddr: UInt32) {
        inaddr = fromInAddr
    }

    init(fromUInt32InHostOrder: UInt32) {
        inaddr = NSSwapHostIntToBig(fromUInt32InHostOrder)
    }

    required init(fromBytesInNetworkOrder: UnsafePointer<Void>) {
        inaddr = UnsafePointer<UInt32>(fromBytesInNetworkOrder).memory
    }

    required init(fromString: String) {
        var addr: UInt32 = 0
        fromString.withCString {
            inet_pton(AF_INET, $0, &addr)
        }
        inaddr = addr
    }

    required init(fromBytesInNetworkOrder: [UInt8]) {
        var addr: UInt32 = 0
        fromBytesInNetworkOrder.withUnsafeBufferPointer {
            addr = UnsafePointer<UInt32>($0.baseAddress).memory
        }
        inaddr = addr
    }

    var presentation: String {
        var buffer = [Int8](count: Int(INET_ADDRSTRLEN), repeatedValue: 0)
        let p = inet_ntop(AF_INET, &inaddr, &buffer, UInt32(INET_ADDRSTRLEN))
        return String.fromCString(p)!
    }

    var description: String {
        return "IPv4 address: \(presentation)"
    }

    var bytesInNetworkOrder: UnsafePointer<Void> {
        var pointer: UnsafePointer<Void> = nil
        withUnsafePointer(&inaddr) {
            pointer = UnsafePointer<Void>($0)
        }
        return pointer
    }
}

func == (left: IPv4Address, right: IPv4Address) -> Bool {
    return left.inaddr == right.inaddr
}
