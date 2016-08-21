import Foundation
import CocoaLumberjackSwift

public class DebugObserverFactory: ObserverFactory {
    public override init() {

    }

    override public func getObserverForTunnel(tunnel: Tunnel) -> Observer<TunnelEvent>? {
        return DebugTunnelObserver()
    }

    override public func getObserverForProxyServer(server: ProxyServer) -> Observer<ProxyServerEvent>? {
        return DebugProxyServerObserver()
    }

    override public func getObserverForProxySocket(socket: ProxySocket) -> Observer<ProxySocketEvent>? {
        return DebugProxySocketObserver()
    }

    override public func getObserverForAdapterSocket(socket: AdapterSocket) -> Observer<AdapterSocketEvent>? {
        return DebugAdapterSocketObserver()
    }
}

public class DebugTunnelObserver: Observer<TunnelEvent> {
    override public func signal(event: TunnelEvent) {
        switch event {
        case .ReceivedRequest,
             .Closed:
            DDLogInfo("\(event)")
        case .Opened,
             .ConnectedToRemote,
             .UpdatingAdapterSocket:
            DDLogVerbose("\(event)")
        case .CloseCalled,
             .ForceCloseCalled,
             .ReceivedReadySignal,
             .ProxySocketReadData,
             .ProxySocketWroteData,
             .AdapterSocketReadData,
             .AdapterSocketWroteData:
            DDLogDebug("\(event)")
        }
    }
}

public class DebugProxySocketObserver: Observer<ProxySocketEvent> {
    override public func signal(event: ProxySocketEvent) {
        switch event {
        case .ErrorOccured:
            DDLogError("\(event)")
        case .Disconnected,
             .ReceivedRequest:
            DDLogInfo("\(event)")
        case .SocketOpened,
             .ReceivedResponse,
             .ReadyForForward:
            DDLogVerbose("\(event)")
        case .DisconnectCalled,
             .ForceDisconnectCalled,
             .ReadData,
             .WroteData:
            DDLogDebug("\(event)")
        }
    }
}

public class DebugAdapterSocketObserver: Observer<AdapterSocketEvent> {
    override public func signal(event: AdapterSocketEvent) {
        switch event {
        case .ErrorOccured:
            DDLogError("\(event)")
        case .Disconnected,
             .Connected:
            DDLogInfo("\(event)")
        case .SocketOpened,
             .ReadyForForward:
            DDLogVerbose("\(event)")
        case .DisconnectCalled,
             .ForceDisconnectCalled,
             .ReadData,
             .WroteData:
            DDLogDebug("\(event)")
        }
    }
}

public class DebugProxyServerObserver: Observer<ProxyServerEvent> {
    override public func signal(event: ProxyServerEvent) {
        switch event {
        case .Started,
             .Stopped:
            DDLogInfo("\(event)")
        case .NewSocketAccepted,
             .TunnelClosed:
            DDLogVerbose("\(event)")
        }
    }
}
