import Foundation

public class ObserverFactory {
    public static var currentFactory: ObserverFactory?

    public init() {
    }

    public func getObserverForTunnel(tunnel: Tunnel) -> Observer<TunnelEvent>? {
        return nil
    }

    public func getObserverForAdapterSocket(socket: AdapterSocket) -> Observer<AdapterSocketEvent>? {
        return nil
    }

    public func getObserverForProxySocket(socket: ProxySocket) -> Observer<ProxySocketEvent>? {
        return nil
    }

    public func getObserverForProxyServer(server: ProxyServer) -> Observer<ProxyServerEvent>? {
        return nil
    }

    public func getObserverForRuleManager(manager: RuleManager) -> Observer<RuleMatchEvent>? {
        return nil
    }
}
