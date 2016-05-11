import Foundation
import MMDB

class GeoIP {
    static let db = MMDB()

    static func LookUp(ip: String) -> MMDBCountry? {
        return GeoIP.db?.lookup(ip)
    }
}
