import Quick
import Nimble
@testable import NEKit

class HTTPURLSpec: QuickSpec {
    override func spec() {
        let testCases: [(String, Bool, String?, String?, Int?, String)] = [
            ("http://google.com/ncr", true, "http", "google.com", nil, "ncr"),
            ("http://google.com/", true, "http", "google.com", nil, ""),
            ("http://google.com:8080/", true, "http", "google.com", 8080, ""),
            ("http://google.com:8080/ccc/aaa/vvv", true, "http", "google.com", 8080, "ccc/aaa/vvv"),
            ("https://google.com/ncr", true, "https", "google.com", nil, "ncr"),
            ("https://google.com/", true, "https", "google.com", nil, ""),
            ("https://google.com:8080/", true, "https", "google.com", 8080, ""),
            ("https://google.com:8080/ccc/aaa/vvv", true, "https", "google.com", 8080, "ccc/aaa/vvv"),
            ("https://google.com::8080/ccc/aaa/vvv", false, "", "", nil, ""),
            ("google.com/ncr", true, nil, "google.com", nil, "ncr"),
            ("google.com/", true, nil, "google.com", nil, ""),
            ("google.com:8080/", true, nil, "google.com", 8080, ""),
            ("google.com:8080/ccc/aaa/vvv", true, nil, "google.com", 8080, "ccc/aaa/vvv"),
            ("google.com::8080/ccc/aaa/vvv", false, "", "", nil, ""),
            ("/ccc/aaa/vvv", true, nil, nil, nil, "ccc/aaa/vvv"),
        ]
        
        it("can parse urls") {
            for test in testCases {
                let url = HTTPURL(string: test.0)
                if test.1 {
                    let url = url!
                    expect(url.scheme == test.2) == true
                    expect(url.host == test.3) == true
                    expect(url.port == test.4) == true
                    expect(url.relativePath).to(equal(test.5))
                } else {
                    expect(url).to(beNil())
                }
            }
        }
    }
}
