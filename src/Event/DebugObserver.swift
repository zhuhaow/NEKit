import Foundation
import CocoaLumberjackSwift

open class DebugObserverFactory: ObserverFactory {
    public override init() {}

    override open func getObserverForTunnel(_ tunnel: Tunnel) -> Observer<TunnelEvent>? {
        return DebugTunnelObserver()
    }

    override open func getObserverForProxyServer(_ server: ProxyServer) -> Observer<ProxyServerEvent>? {
        return DebugProxyServerObserver()
    }

    override open func getObserverForProxySocket(_ socket: ProxySocket) -> Observer<ProxySocketEvent>? {
        return DebugProxySocketObserver()
    }

    override open func getObserverForAdapterSocket(_ socket: AdapterSocket) -> Observer<AdapterSocketEvent>? {
        return DebugAdapterSocketObserver()
    }

    open override func getObserverForRuleManager(_ manager: RuleManager) -> Observer<RuleMatchEvent>? {
        return DebugRuleManagerObserver()
    }
}

open class DebugTunnelObserver: Observer<TunnelEvent> {
    override open func signal(_ event: TunnelEvent) {
        switch event {
        case .receivedRequest,
             .closed:
            DDLogInfo("\(event)")
        case .opened,
             .connectedToRemote,
             .updatingAdapterSocket:
            DDLogVerbose("\(event)")
        case .closeCalled,
             .forceCloseCalled,
             .receivedReadySignal,
             .proxySocketReadData,
             .proxySocketWroteData,
             .adapterSocketReadData,
             .adapterSocketWroteData:
            DDLogDebug("\(event)")
        }
    }
}

open class DebugProxySocketObserver: Observer<ProxySocketEvent> {
    override open func signal(_ event: ProxySocketEvent) {
        switch event {
        case .errorOccured:
            DDLogError("\(event)")
        case .disconnected,
             .receivedRequest:
            DDLogInfo("\(event)")
        case .socketOpened,
             .askedToResponseTo,
             .readyForForward:
            DDLogVerbose("\(event)")
        case .disconnectCalled,
             .forceDisconnectCalled,
             .readData,
             .wroteData:
            DDLogDebug("\(event)")
        }
    }
}

open class DebugAdapterSocketObserver: Observer<AdapterSocketEvent> {
    override open func signal(_ event: AdapterSocketEvent) {
        switch event {
        case .errorOccured:
            DDLogError("\(event)")
        case .disconnected,
             .connected:
            DDLogInfo("\(event)")
        case .socketOpened,
             .readyForForward:
            DDLogVerbose("\(event)")
        case .disconnectCalled,
             .forceDisconnectCalled,
             .readData,
             .wroteData:
            DDLogDebug("\(event)")
        }
    }
}

open class DebugProxyServerObserver: Observer<ProxyServerEvent> {
    override open func signal(_ event: ProxyServerEvent) {
        switch event {
        case .started,
             .stopped:
            DDLogInfo("\(event)")
        case .newSocketAccepted,
             .tunnelClosed:
            DDLogVerbose("\(event)")
        }
    }
}

open class DebugRuleManagerObserver: Observer<RuleMatchEvent> {
    open override func signal(_ event: RuleMatchEvent) {
        switch event {
        case .ruleDidNotMatch, .dnsRuleMatched:
            DDLogVerbose("\(event)")
        case .ruleMatched:
            DDLogInfo("\(event)")
        }
    }
}
