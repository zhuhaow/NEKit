import Quick
import Nimble
@testable import NEKit

class IPRangeSpec: QuickSpec {
    override func spec() {
        let cidrWrongSamples = [
            ("127.0.0.132", IPRangeError.invalidCIDRFormat),
            ("13.1242.1241.1/3", IPRangeError.invalidCIDRFormat),
            ("123.122.33.21/35", IPRangeError.invalidMask),
            ("123.123.131.12/-1", IPRangeError.invalidCIDRFormat),
            ("123.123.131.12/", IPRangeError.invalidCIDRFormat)
        ]

        let cidrCorrectSamples = [
            ("127.0.0.0/32", [IPAddress(fromString: "127.0.0.1")!]),
            ("127.0.0.0/31", [IPAddress(fromString: "127.0.0.1")!]),
            ("127.0.0.0/1", [IPAddress(fromString: "127.0.0.1")!])
        ]

        let rangeWrongSamples = [
            ("127.0.0.132", IPRangeError.invalidRangeFormat),
            ("13.1242.1241.1+3", IPRangeError.invalidRangeFormat),
            ("255.255.255.255+1", IPRangeError.invalidRange),
            ("0.0.0.1+4294967295", IPRangeError.invalidRange),
            ("123.123.131.12+", IPRangeError.invalidRangeFormat),
            ("12.124.51.23-1", IPRangeError.invalidRangeFormat)
        ]

        let rangeCorrectSamples = [
            ("127.0.0.1+3", [IPAddress(fromString: "127.0.0.1")!]),
            ("255.255.255.255+0", [IPAddress(fromString: "255.255.255.255")!]),
            ("0.0.0.0+4294967295", [IPAddress(fromString: "0.0.0.0")!])
        ]

        let ipSamples = [
            ("127.0.0.1", [IPAddress(fromString: "127.0.0.1")!])
        ]

        describe("IPRange initailization") {
            it("can be initailized with CIDR IP representation") {
                for sample in cidrWrongSamples {
                    expect {try IPRange(withCIDRString: sample.0)}.to(throwError(sample.1))
                }

                for sample in cidrCorrectSamples {
                    expect {try IPRange(withCIDRString: sample.0)}.toNot(throwError())
                }
            }

            it("can be initailized with IP range representation") {
                for sample in rangeWrongSamples {
                    expect {try IPRange(withRangeString: sample.0)}.to(throwError(sample.1))
                }

                for sample in rangeCorrectSamples {
                    expect {try IPRange(withRangeString: sample.0)}.toNot(throwError())
                }
            }

            it("can select the best way to initailize") {

                for sample in cidrCorrectSamples {
                    expect {try IPRange(withString: sample.0)}.toNot(throwError())
                }

                for sample in rangeCorrectSamples {
                    expect {try IPRange(withString: sample.0)}.toNot(throwError())
                }

                for sample in ipSamples {
                    expect {try IPRange(withString: sample.0)}.toNot(throwError())
                }
            }
        }
        
        describe("IPRange matching") {
            it ("Can match IPv4 address with mask") {
                let range = try! IPRange(withString: "8.8.8.8/24")
                expect(range.contains(ip: IPAddress(fromString: "8.8.8.0")!)).to(beTrue())
                expect(range.contains(ip: IPAddress(fromString: "8.8.8.255")!)).to(beTrue())
                expect(range.contains(ip: IPAddress(fromString: "8.8.7.255")!)).to(beFalse())
                expect(range.contains(ip: IPAddress(fromString: "8.8.9.0")!)).to(beFalse())
            }
        }
    }
}
