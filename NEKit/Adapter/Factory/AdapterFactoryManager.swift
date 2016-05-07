import Foundation

class AdapterFactoryManager {
    var factoryDict: [String: AdapterFactoryProtocol]
    
    subscript(index: String) -> AdapterFactoryProtocol? {
        get { return factoryDict[index] }
        set { factoryDict[index] = newValue }
    }
    
    init(factoryDict: [String: AdapterFactoryProtocol]) {
        self.factoryDict = factoryDict
    }
}
