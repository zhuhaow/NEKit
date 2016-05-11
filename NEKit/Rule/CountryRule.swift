import Foundation

class CountryRule: Rule {
    let countryCode: String
    let match: Bool
    let adapterFactory: AdapterFactoryProtocol

    init(countryCode: String, match: Bool, adapterFactory: AdapterFactoryProtocol) {
        self.countryCode = countryCode
        self.match = match
        self.adapterFactory = adapterFactory
        super.init()
    }

    override func match(request: ConnectRequest) -> AdapterFactoryProtocol? {
        if (request.country != countryCode) != match {
            return adapterFactory
        }
        return nil
    }
}
