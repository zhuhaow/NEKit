import Quick
import Nimble
@testable import NEKit

class IPRangeSpec: QuickSpec {
    override func spec() {
        describe("IPRange initailization") {
            it("can be initailized with CIDR IP representation") {
                // CIDR must have a "/"
                expect {try IPRange(withCIDRString: "127.0.0.132")}.to(throwError(IPRangeError.InvalidCIDRFormat))

                // IP address has to be valid
                expect {try IPRange(withCIDRString: "13.1242.1241.1/3")}.to(throwError(IPRangeError.InvalidCIDRFormat))

                // mask has to be valid
                expect {try IPRange(withCIDRString: "123.122.33.21/35")}.to(throwError(IPRangeError.InvalidCIDRFormat))
                expect {try IPRange(withCIDRString: "123.123.131.12/-1")}.to(throwError(IPRangeError.InvalidCIDRFormat))

                expect {try IPRange(withCIDRString: "127.0.0.0/31")}.toNot(throwError())

                let range = try! IPRange(withCIDRString: "127.0.0.0/31")
                
                expect(range.baseIP.presentation) == "127.0.0.0"
                expect(range.range) == 2 - 1
            }
        }
    }
}
