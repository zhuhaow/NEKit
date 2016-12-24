import Quick
import Nimble
@testable import NEKit

class IPAddressSpec: QuickSpec {
    override func spec() {
        it("can init from IPv4 string") {
            let ip = IPAddress(fromString: "127.0.0.1")
            expect(ip).toNot(beNil())
            expect(ip?.family) == .IPv4
        }
        
        it("can init from IPv6 string") {
            let ip = IPAddress(fromString: "::1")
            expect(ip).toNot(beNil())
            expect(ip?.family) == .IPv6
            
            expect(ip!.address.asUInt128) == 1
        }
        
        it("can compare IPv6 address") {
            let ip1 = IPAddress(fromString: "2001::FFFF:FFFF:FFFF:1")!
            let ip2 = IPAddress(fromString: "2001::FFFF:FFFF:FFFF:2")!
            let ip3 = IPAddress(fromString: "2003:1234:3de2:3123::1")!
            expect(ip1).to(beLessThan(ip2))
            expect(ip1).to(beLessThan(ip3))
        }
        
        it("can advance IPv6 address") {
            let ip1 = IPAddress(fromString: "2001::1")!
            let ip2 = ip1.advanced(by: 3)
            expect(ip2).toNot(beNil())
            expect(ip1).to(beLessThan(ip2!))
            expect(ip2!.presentation) == "2001::4"
        }
    }
}
