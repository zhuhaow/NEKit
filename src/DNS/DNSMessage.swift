import Foundation
import CocoaLumberjackSwift

class DNSMessage {
    //    var sourceAddress: IPv4Address?
    //    var sourcePort: Port?
    //    var destinationAddress: IPv4Address?
    //    var destinationPort: Port?
    var transactionID: UInt16 = 0
    var messageType: DNSMessageType = .Query
    var authoritative: Bool = false
    var truncation: Bool = false
    var recursionDesired: Bool = false
    var recursionAvailable: Bool = false
    var status: DNSReturnStatus = .Success
    var queries: [DNSQuery] = []
    var answers: [DNSResource] = []
    var nameservers: [DNSResource] = []
    var addtionals: [DNSResource] = []

    var payload: NSData!

    var mutablePayload: NSMutableData {
        // swiftlint:disable:next force_cast
        return payload as! NSMutableData
    }

    var bytesLength: Int {
        var len = 12 + queries.reduce(0) {
            $0 + $1.bytesLength
        }
        len += answers.reduce(0) {
            $0 + $1.bytesLength
        }
        len += nameservers.reduce(0) {
            $0 + $1.bytesLength
        }
        len += addtionals.reduce(0) {
            $0 + $1.bytesLength
        }
        return len
    }

    var resolvedIPv4Address: IPv4Address? {
        for answer in answers {
            if let address = answer.ipv4Address {
                return address
            }
        }
        return nil
    }

    init() {}

    init?(payload: NSData) {
        self.payload = payload
        let scanner = BinaryDataScanner(data: payload, littleEndian: false)

        transactionID = scanner.read16()!

        var bytes = scanner.readByte()!
        if bytes & 0x80 > 0 {
            messageType = .Response
        } else {
            messageType = .Query
        }

        // ignore OP code

        authoritative = bytes & 0x04 > 0
        truncation = bytes & 0x02 > 0
        recursionDesired = bytes & 0x01 > 0

        bytes = scanner.readByte()!
        recursionAvailable = bytes & 0x80 > 0
        if let status = DNSReturnStatus(rawValue: bytes & 0x0F) {
            self.status = status
        } else {
            DDLogError("Received DNS response with unknown status: \(bytes & 0x0F).")
            self.status = .ServerFailure
        }

        let queryCount = scanner.read16()!
        let answerCount = scanner.read16()!
        let nameserverCount = scanner.read16()!
        let addtionalCount = scanner.read16()!

        for _ in 0..<queryCount {
            queries.append(DNSQuery(payload: payload, offset: scanner.position, base: 0)!)
            scanner.advanceBy(queries.last!.bytesLength)
        }

        for _ in 0..<answerCount {
            answers.append(DNSResource(payload: payload, offset: scanner.position, base: 0)!)
            scanner.advanceBy(answers.last!.bytesLength)
        }

        for _ in 0..<nameserverCount {
            nameservers.append(DNSResource(payload: payload, offset: scanner.position, base: 0)!)
            scanner.advanceBy(nameservers.last!.bytesLength)
        }

        for _ in 0..<addtionalCount {
            addtionals.append(DNSResource(payload: payload, offset: scanner.position, base: 0)!)
            scanner.advanceBy(addtionals.last!.bytesLength)
        }

    }

    func buildMessage() -> Bool {
        payload = NSMutableData(length: bytesLength)
        if transactionID == 0 {
            transactionID = UInt16(arc4random_uniform(UInt32(UInt16.max)))
        }
        setPayloadWithUInt16(transactionID, at: 0, swap: true)
        var byte: UInt8 = 0
        byte += messageType.rawValue << 7
        if authoritative {
            byte += 1 << 2
        }
        if truncation {
            byte += 1 << 1
        }
        if recursionDesired {
            byte += 1
        }
        setPayloadWithUInt8(byte, at: 2)
        byte = 0
        if recursionAvailable {
            byte += 1 << 7
        }

        byte += status.rawValue

        setPayloadWithUInt8(byte, at: 3)
        setPayloadWithUInt16(UInt16(queries.count), at: 4, swap: true)
        setPayloadWithUInt16(UInt16(answers.count), at: 6, swap: true)
        setPayloadWithUInt16(UInt16(nameservers.count), at: 8, swap: true)
        setPayloadWithUInt16(UInt16(addtionals.count), at: 10, swap: true)

        return writeAllRecordAt(12)
    }

    // swiftlint:disable variable_name
    func setPayloadWithUInt8(value: UInt8, at: Int) {
        var v = value
        mutablePayload.replaceBytesInRange(NSRange(location: at, length: 1), withBytes: &v)
    }

    func setPayloadWithUInt16(value: UInt16, at: Int, swap: Bool = false) {
        var v: UInt16
        if swap {
            v = NSSwapHostShortToBig(value)
        } else {
            v = value
        }
        mutablePayload.replaceBytesInRange(NSRange(location: at, length: 2), withBytes: &v)
    }

    func setPayloadWithUInt32(value: UInt32, at: Int, swap: Bool = false) {
        var v: UInt32
        if swap {
            v = NSSwapHostIntToBig(value)
        } else {
            v = value
        }
        mutablePayload.replaceBytesInRange(NSRange(location: at, length: 4), withBytes: &v)
    }

    func setPayloadWithData(data: NSData, at: Int, length: Int? = nil, from: Int = 0) {
        var length = length
        if length == nil {
            length = data.length - from
        }
        let pointer = data.bytes.advancedBy(from)
        mutablePayload.replaceBytesInRange(NSRange(location: at, length: length!), withBytes: pointer)
    }

    func resetPayloadAt(at: Int, length: Int) {
        mutablePayload.resetBytesInRange(NSRange(location: at, length: length))
    }

    private func writeAllRecordAt(at: Int) -> Bool {
        var position = at
        for query in queries {
            guard writeDNSQuery(query, at: position) else {
                return false
            }
            position += query.bytesLength
        }
        for resources in [answers, nameservers, addtionals] {
            for resource in resources {
                guard writeDNSResource(resource, at: position) else {
                    return false
                }
                position += resource.bytesLength
            }
        }
        return true
    }

    private func writeDNSQuery(query: DNSQuery, at: Int) -> Bool {
        guard DNSNameConverter.setName(query.name, toData: mutablePayload, at: at) else {
            return false
        }
        setPayloadWithUInt16(query.type.rawValue, at: at + query.nameBytesLength, swap: true)
        setPayloadWithUInt16(query.klass.rawValue, at: at + query.nameBytesLength + 2, swap: true)
        return true
    }

    private func writeDNSResource(resource: DNSResource, at: Int) -> Bool {
        guard DNSNameConverter.setName(resource.name, toData: mutablePayload, at: at) else {
            return false
        }
        setPayloadWithUInt16(resource.type.rawValue, at: at + resource.nameBytesLength, swap: true)
        setPayloadWithUInt16(resource.klass.rawValue, at: at + resource.nameBytesLength + 2, swap: true)
        setPayloadWithUInt32(resource.TTL, at: at + resource.nameBytesLength + 4, swap: true)
        setPayloadWithUInt16(resource.dataLength, at: at + resource.nameBytesLength + 8, swap: true)
        setPayloadWithData(resource.data, at: at + resource.nameBytesLength + 10)
        return true
    }
}

class DNSQuery {
    let name: String
    let type: DNSType
    let klass: DNSClass
    let nameBytesLength: Int

    init(name: String, type: DNSType = .A, klass: DNSClass = .Internet) {
        self.name = name.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "."))
        self.type = type
        self.klass = klass
        self.nameBytesLength = name.utf8.count + 2
    }

    init?(payload: NSData, offset: Int, base: Int = 0) {
        (self.name, self.nameBytesLength) = DNSNameConverter.getNamefromData(payload, offset: offset, base: base)

        let scanner = BinaryDataScanner(data: payload, littleEndian: false)
        scanner.skipTo(offset + self.nameBytesLength)

        guard let type = DNSType(rawValue: scanner.read16()!) else {
            DDLogError("Received DNS packet with unknown type.")
            return nil
        }
        self.type = type

        guard let klass = DNSClass(rawValue: scanner.read16()!) else {
            DDLogError("Received DNS packet with unknown class.")
            return nil
        }
        self.klass = klass

    }


    var bytesLength: Int {
        return nameBytesLength + 4
    }
}

class DNSResource {
    let name: String
    let type: DNSType
    let klass: DNSClass
    let TTL: UInt32
    let dataLength: UInt16
    let data: NSData

    let nameBytesLength: Int

    init(name: String, type: DNSType = .A, klass: DNSClass = .Internet, TTL: UInt32 = 300, data: NSData) {
        self.name = name
        self.type = type
        self.klass = klass
        self.TTL = TTL
        dataLength = UInt16(data.length)
        self.data = data
        self.nameBytesLength = name.utf8.count + 2
    }

    static func ARecord(name: String, TTL: UInt32 = 300, address: IPv4Address) -> DNSResource {
        return DNSResource(name: name, type: .A, klass: .Internet, TTL: TTL, data: address.dataInNetworkOrder)
    }

    init?(payload: NSData, offset: Int, base: Int = 0) {
        (self.name, self.nameBytesLength) = DNSNameConverter.getNamefromData(payload, offset: offset, base: base)

        let scanner = BinaryDataScanner(data: payload, littleEndian: false)
        scanner.skipTo(offset + self.nameBytesLength)

        guard let type = DNSType(rawValue: scanner.read16()!) else {
            DDLogError("Received DNS packet with unknown type.")
            return nil
        }
        self.type = type

        guard let klass = DNSClass(rawValue: scanner.read16()!) else {
            DDLogError("Received DNS packet with unknown class.")
            return nil
        }
        self.klass = klass
        self.TTL = scanner.read32()!
        dataLength = scanner.read16()!
        self.data = payload.subdataWithRange(NSRange(location: scanner.position, length: Int(dataLength)))
    }

    var bytesLength: Int {
        return nameBytesLength + 10 + Int(dataLength)
    }

    var ipv4Address: IPv4Address? {
        guard type == .A else {
            return nil
        }
        return IPv4Address(fromBytesInNetworkOrder: data.bytes)
    }
}

class DNSNameConverter {
    static func setName(name: String, toData data: NSMutableData, at: Int) -> Bool {
        let labels = name.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "."))
        var position = at
        let headPointer = UnsafeMutablePointer<UInt8>(data.mutableBytes)
        for label in labels {
            let len = label.utf8.count
            guard len != 0 else {
                // invalid domain name
                return false
            }
            headPointer.advancedBy(position).memory = UInt8(len)
            position += 1
            label.withCString {
                // note the ending zero is ignored since the range does not contain it.
                data.replaceBytesInRange(NSRange(location: position, length: len), withBytes: $0)
            }
            position += len
        }
        headPointer.advancedBy(position).memory = 0
        return true
    }

    static func getNamefromData(data: NSData, offset: Int, base: Int = 0) -> (String, Int) {
        let scanner = BinaryDataScanner(data: data, littleEndian: false)
        scanner.skipTo(offset)

        var len: UInt8 = 0
        var name = ""
        var currentReadBytes = 0
        var jumped = false
        var nameBytesLength = 0
        repeat {
            let length = scanner.read16()!
            // is this a pointer?
            if length & 0xC000 == 0xC000 {
                if !jumped {
                    // save the length position
                    nameBytesLength = 2 + currentReadBytes
                    jumped = true
                }
                scanner.skipTo(Int(length & 0x3FFF) + base)
            } else {
                scanner.advanceBy(-2)
            }

            len = scanner.readByte()!
            currentReadBytes += 1
            if len == 0 {
                break
            }

            currentReadBytes += Int(len)
            guard let label = NSString(bytes: scanner.current, length: Int(len), encoding: NSUTF8StringEncoding) else {
                return ("", currentReadBytes)
            }
            // this is not efficient, but won't take much time, so maybe I'll optimize it later
            name = name.stringByAppendingFormat(".%@", label)
            scanner.advanceBy(Int(len))
        } while true

        if !jumped {
            nameBytesLength = currentReadBytes
        }

        return (name.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: ".")), nameBytesLength)
    }
}
