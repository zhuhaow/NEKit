import Foundation
import MMDB

public class GeoIP {
    public static let database = MMDB()

    public static func LookUp(ipAddress: String) -> MMDBCountry? {
        return GeoIP.database?.lookup(ipAddress)
    }
}
