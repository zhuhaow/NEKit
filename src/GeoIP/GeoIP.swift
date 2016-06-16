import Foundation
import MMDB

class GeoIP {
    static let database = MMDB()

    static func LookUp(ipAddress: String) -> MMDBCountry? {
        return GeoIP.database?.lookup(ipAddress)
    }
}
