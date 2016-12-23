import Foundation
import CocoaLumberjackSwift

open class DNSMessage {
    //    var sourceAddress: IPv4Address?
    //    var sourcePort: Port?
    //    var destinationAddress: IPv4Address?
    //    var destinationPort: Port?
    open var transactionID: UInt16 = 0
    open var messageType: DNSMessageType = .query
    open var authoritative: Bool = false
    open var truncation: Bool = false
    open var recursionDesired: Bool = false
    open var recursionAvailable: Bool = false
    open var status: DNSReturnStatus = .success
    open var queries: [DNSQuery] = []
    open var answers: [DNSResource] = []
    open var nameservers: [DNSResource] = []
    open var addtionals: [DNSResource] = []

    var payload: Data!

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

    var resolvedIPv4Address: IPAddress? {
        for answer in answers {
            if let address = answer.ipv4Address {
                return address
            }
        }
        return nil
    }

    var type: DNSType? {
        return queries.first?.type
    }

    init() {}

    init?(payload: Data) {
        self.payload = payload
        let scanner = BinaryDataScanner(data: payload, littleEndian: false)

        transactionID = scanner.read16()!

        var bytes = scanner.readByte()!
        if bytes & 0x80 > 0 {
            messageType = .response
        } else {
            messageType = .query
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
            self.status = .serverFailure
        }

        let queryCount = scanner.read16()!
        let answerCount = scanner.read16()!
        let nameserverCount = scanner.read16()!
        let addtionalCount = scanner.read16()!

        for _ in 0..<queryCount {
            queries.append(DNSQuery(payload: payload, offset: scanner.position, base: 0)!)
            scanner.advance(by: queries.last!.bytesLength)
        }

        for _ in 0..<answerCount {
            answers.append(DNSResource(payload: payload, offset: scanner.position, base: 0)!)
            scanner.advance(by: answers.last!.bytesLength)
        }

        for _ in 0..<nameserverCount {
            nameservers.append(DNSResource(payload: payload, offset: scanner.position, base: 0)!)
            scanner.advance(by: nameservers.last!.bytesLength)
        }

        for _ in 0..<addtionalCount {
            addtionals.append(DNSResource(payload: payload, offset: scanner.position, base: 0)!)
            scanner.advance(by: addtionals.last!.bytesLength)
        }

    }

    func buildMessage() -> Bool {
        payload = Data(count: bytesLength)
        if transactionID == 0 {
            transactionID = UInt16(arc4random_uniform(UInt32(UInt16.max)))
        }
        setPayloadWithUInt16(transactionID, at: 0, swap: true)
        var byte: UInt8 = 0
        byte += messageType.rawValue << 7
        if authoritative {
            byte += 4
        }
        if truncation {
            byte += 2
        }
        if recursionDesired {
            byte += 1
        }
        setPayloadWithUInt8(byte, at: 2)
        byte = 0
        if recursionAvailable {
            byte += 128
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
    func setPayloadWithUInt8(_ value: UInt8, at: Int) {
        var v = value
        withUnsafeBytes(of: &v) {
            payload.replaceSubrange(at..<at+1, with: $0)
        }
    }

    func setPayloadWithUInt16(_ value: UInt16, at: Int, swap: Bool = false) {
        var v: UInt16
        if swap {
            v = NSSwapHostShortToBig(value)
        } else {
            v = value
        }
        withUnsafeBytes(of: &v) {
            payload.replaceSubrange(at..<at+2, with: $0)
        }
    }

    func setPayloadWithUInt32(_ value: UInt32, at: Int, swap: Bool = false) {
        var v: UInt32
        if swap {
            v = NSSwapHostIntToBig(value)
        } else {
            v = value
        }
        withUnsafeBytes(of: &v) {
            payload.replaceSubrange(at..<at+4, with: $0)
        }
    }

    func setPayloadWithData(_ data: Data, at: Int, length: Int? = nil, from: Int = 0) {
        var length = length
        if length == nil {
            length = data.count - from
        }

        payload.withUnsafeMutableBytes {
            data.copyBytes(to: $0+at, from: from..<from+length!)
        }
    }

    func resetPayloadAt(_ at: Int, length: Int) {
        payload.resetBytes(in: at..<at+length)
    }

    fileprivate func writeAllRecordAt(_ at: Int) -> Bool {
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

    fileprivate func writeDNSQuery(_ query: DNSQuery, at: Int) -> Bool {
        guard DNSNameConverter.setName(query.name, toData: &payload!, at: at) else {
            return false
        }
        setPayloadWithUInt16(query.type.rawValue, at: at + query.nameBytesLength, swap: true)
        setPayloadWithUInt16(query.klass.rawValue, at: at + query.nameBytesLength + 2, swap: true)
        return true
    }

    fileprivate func writeDNSResource(_ resource: DNSResource, at: Int) -> Bool {
        guard DNSNameConverter.setName(resource.name, toData: &payload!, at: at) else {
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

open class DNSQuery {
    open let name: String
    open let type: DNSType
    open let klass: DNSClass
    let nameBytesLength: Int

    init(name: String, type: DNSType = .a, klass: DNSClass = .internet) {
        self.name = name.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        self.type = type
        self.klass = klass
        self.nameBytesLength = name.utf8.count + 2
    }

    init?(payload: Data, offset: Int, base: Int = 0) {
        (self.name, self.nameBytesLength) = DNSNameConverter.getNamefromData(payload, offset: offset, base: base)

        let scanner = BinaryDataScanner(data: payload, littleEndian: false)
        scanner.skip(to: offset + self.nameBytesLength)

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

open class DNSResource {
    open let name: String
    open let type: DNSType
    open let klass: DNSClass
    open let TTL: UInt32
    let dataLength: UInt16
    open let data: Data

    let nameBytesLength: Int

    init(name: String, type: DNSType = .a, klass: DNSClass = .internet, TTL: UInt32 = 300, data: Data) {
        self.name = name
        self.type = type
        self.klass = klass
        self.TTL = TTL
        dataLength = UInt16(data.count)
        self.data = data
        self.nameBytesLength = name.utf8.count + 2
    }

    static func ARecord(_ name: String, TTL: UInt32 = 300, address: IPAddress) -> DNSResource {
        return DNSResource(name: name, type: .a, klass: .internet, TTL: TTL, data: address.dataInNetworkOrder)
    }

    init?(payload: Data, offset: Int, base: Int = 0) {
        (self.name, self.nameBytesLength) = DNSNameConverter.getNamefromData(payload, offset: offset, base: base)

        let scanner = BinaryDataScanner(data: payload, littleEndian: false)
        scanner.skip(to: offset + self.nameBytesLength)

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
        self.data = payload.subdata(in: scanner.position..<scanner.position+Int(dataLength))
    }

    var bytesLength: Int {
        return nameBytesLength + 10 + Int(dataLength)
    }

    var ipv4Address: IPAddress? {
        guard type == .a else {
            return nil
        }
        return IPAddress(fromBytesInNetworkOrder: (data as NSData).bytes)
    }
}

class DNSNameConverter {
    static func setName(_ name: String, toData data: inout Data, at: Int) -> Bool {
        let labels = name.components(separatedBy: CharacterSet(charactersIn: "."))
        var position = at

        for label in labels {
            let len = label.utf8.count
            guard len != 0 else {
                // invalid domain name
                return false
            }
            data.withUnsafeMutableBytes { (ptr: UnsafeMutablePointer<UInt8>) in
                ptr.advanced(by: position).pointee = UInt8(len)
            }
            position += 1

            data.replaceSubrange(position..<position+len, with: label.data(using: .utf8)!)
            position += len
        }
        data.withUnsafeMutableBytes { (ptr: UnsafeMutablePointer<UInt8>) in
            ptr.advanced(by: position).pointee = 0
        }
        return true
    }

    static func getNamefromData(_ data: Data, offset: Int, base: Int = 0) -> (String, Int) {
        let scanner = BinaryDataScanner(data: data, littleEndian: false)
        scanner.skip(to: offset)

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
                scanner.skip(to: Int(length & 0x3FFF) + base)
            } else {
                scanner.advance(by: -2)
            }

            len = scanner.readByte()!
            currentReadBytes += 1
            if len == 0 {
                break
            }

            currentReadBytes += Int(len)

            guard let label = String(bytes: scanner.data.subdata(in: scanner.position..<scanner.position+Int(len)), encoding: .utf8) else {
                return ("", currentReadBytes)
            }
            // this is not efficient, but won't take much time, so maybe I'll optimize it later
            name = name.appendingFormat(".%@", label)
            scanner.advance(by: Int(len))
        } while true

        if !jumped {
            nameBytesLength = currentReadBytes
        }

        return (name.trimmingCharacters(in: CharacterSet(charactersIn: ".")), nameBytesLength)
    }
}
