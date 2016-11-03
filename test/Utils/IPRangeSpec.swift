import Quick
import Nimble
@testable import NEKit

class IPRangeSpec: QuickSpec {
    override func spec() {
        let cidrWrongSamples = [
            ("127.0.0.132", IPRangeError.invalidCIDRFormat),
            ("13.1242.1241.1/3", IPRangeError.invalidCIDRFormat),
            ("123.122.33.21/35", IPRangeError.invalidCIDRFormat),
            ("123.123.131.12/-1", IPRangeError.invalidCIDRFormat),
            ("123.123.131.12/", IPRangeError.invalidCIDRFormat)
        ]

        let cidrCorrectSamples = [
            ("127.0.0.0/32", [IPv4Address(fromString: "127.0.0.1")!]),
            ("127.0.0.0/31", [IPv4Address(fromString: "127.0.0.1")!]),
            ("127.0.0.0/1", [IPv4Address(fromString: "127.0.0.1")!])
        ]

        let rangeWrongSamples = [
            ("127.0.0.132", IPRangeError.invalidRangeFormat),
            ("13.1242.1241.1+3", IPRangeError.invalidRangeFormat),
            ("255.255.255.255+1", IPRangeError.rangeIsTooLarge),
            ("0.0.0.1+4294967295", IPRangeError.rangeIsTooLarge),
            ("123.123.131.12+", IPRangeError.invalidRangeFormat),
            ("12.124.51.23-1", IPRangeError.invalidRangeFormat)
        ]

        let rangeCorrectSamples = [
            ("127.0.0.1+3", [IPv4Address(fromString: "127.0.0.1")!]),
            ("255.255.255.255+0", [IPv4Address(fromString: "255.255.255.255")!]),
            ("0.0.0.0+4294967295", [IPv4Address(fromString: "0.0.0.0")!])
        ]

        let ipSamples = [
            ("127.0.0.1", [IPv4Address(fromString: "127.0.0.1")!])
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

            xit("can select the best way to initailize") {
                for sample in cidrWrongSamples {
                    expect {try IPRange(withString: sample.0)}.to(throwError(sample.1))
                }

                for sample in rangeWrongSamples {
                    expect {try IPRange(withString: sample.0)}.toNot(throwError(sample.1))
                }

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
    }
}
