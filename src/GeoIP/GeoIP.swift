import Foundation
import MMDB

open class GeoIP {
    open static let database = MMDB()!

    open static func LookUp(_ ipAddress: String) -> MMDBCountry? {
        return GeoIP.database.lookup(ipAddress)
    }
}
