import Foundation

public enum DNSType: UInt16 {
    // swiftlint:disable:next type_name
    case invalid = 0, a, ns, md, mf, cname, soa, mb, mg, mr, null, wks, ptr, hinfo, minfo, mx, txt, rp, afsdb, x25, isdn, rt, nsap, nsapptr, sig, key, px, gpos, aaaa, loc, nxt, eid, nimloc, srv, atma, naptr, kx, cert, a6, dname, sink, opt, apl, ds, sshfp, rrsig = 46, nsec, dnskey, tkey = 249, tsig, ixfr, axfr, mailb, maila, any
}

public enum DNSMessageType: UInt8 {
    case query, response
}

public enum DNSReturnStatus: UInt8 {
    case success = 0, formatError, serverFailure, nameError, notImplemented, refused
}

public enum DNSClass: UInt16 {
    case internet = 1
}
