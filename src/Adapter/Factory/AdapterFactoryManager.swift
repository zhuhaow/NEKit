import Foundation

class AdapterFactoryManager {
    var factoryDict: [String: AdapterFactoryProtocol]

    subscript(index: String) -> AdapterFactoryProtocol? {
        get {
            if index == "direct" {
                return DirectAdapterFactory()
            }
            return factoryDict[index]
        }
        set { factoryDict[index] = newValue }
    }

    init(factoryDict: [String: AdapterFactoryProtocol]) {
        self.factoryDict = factoryDict
    }
}
