import Foundation

class Rule {
    let name :String?
    
    init() {
        name = nil
    }
    
    func match(request: ConnectRequest) -> AdapterFactoryProtocol? {
        return nil
    }
}

class AllRule : Rule {
    let adapterFactory :AdapterFactoryProtocol
    
    init(adapterFactory: AdapterFactoryProtocol) {
        self.adapterFactory = adapterFactory
        super.init()
    }

    override func match(request :ConnectRequest) -> AdapterFactoryProtocol? {
        return adapterFactory
    }
}

class DirectRule : AllRule {
    init() {
        super.init(adapterFactory: DirectAdapterFactory())
    }
}

