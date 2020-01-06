import Foundation
import MMDB

open class GeoIP {
    // Back in the days, MMDB ships a bundled GeoLite2 database. However, that has changed
    // due to license change of the database. Now developers must initialize it by themselves.
    // In order to maintain the API compatibility while expose the issue ASAP, we set the type
    // to `MMDB!` so it will crash during development if one forgets to initialize it.

    // Please initialize it first!
    public static var database: MMDB!

    public static func LookUp(_ ipAddress: String) -> MMDBCountry? {
        return GeoIP.database.lookup(ipAddress)
    }
}
