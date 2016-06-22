import Foundation

/// This is a very simple wrapper of a dict of type `[String: AdapterFactoryProtocol]`.
///
/// Use it as a normal dict.
class AdapterFactoryManager {
    private var factoryDict: [String: AdapterFactoryProtocol]

    subscript(index: String) -> AdapterFactoryProtocol? {
        get {
            if index == "direct" {
                return DirectAdapterFactory()
            }
            return factoryDict[index]
        }
        set { factoryDict[index] = newValue }
    }

    /**
     Initialize a new factory manager.

     - parameter factoryDict: The factory dict.
     */
    init(factoryDict: [String: AdapterFactoryProtocol]) {
        self.factoryDict = factoryDict
    }
}
