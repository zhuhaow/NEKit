import Foundation

class ListRule: Rule {
    var urls: [NSRegularExpression] = []
    let adapterFactory: AdapterFactoryProtocol

    init(adapterFactory: AdapterFactoryProtocol, urls: [String]) throws {
        self.adapterFactory = adapterFactory
        self.urls = try urls.map {
            try NSRegularExpression(pattern: $0, options: .CaseInsensitive)
        }
    }

    override func match(request: ConnectRequest) -> AdapterFactoryProtocol? {
        for url in urls {
            if let _ = url.firstMatchInString(request.host, options: [], range: NSRange(location: 0, length: request.host.utf16.count)) {
                return adapterFactory
            }
        }
        return nil
    }
}
