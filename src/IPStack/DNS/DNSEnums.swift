import Foundation

enum DNSType: UInt16 {
    // swiftlint:disable:next type_name
    case INVALID = 0, A, NS, MD, MF, CNAME, SOA, MB, MG, MR, NULL, WKS, PTR, HINFO, MINFO, MX, TXT, RP, AFSDB, X25, ISDN, RT, NSAP, NSAPPTR, SIG, KEY, PX, GPOS, AAAA, LOC, NXT, EID, NIMLOC, SRV, ATMA, NAPTR, KX, CERT, A6, DNAME, SINK, OPT, APL, DS, SSHFP, RRSIG = 46, NSEC, DNSKEY, TKEY = 249, TSIG, IXFR, AXFR, MAILB, MAILA, ANY
}

enum DNSMessageType: UInt8 {
    case Query, Response
}

enum DNSReturnStatus: UInt8 {
    case Success = 0, FormatError, ServerFailure, NameError, NotImplemented, Refused
}

enum DNSClass: UInt16 {
    case Internet = 1
}
