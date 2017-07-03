import Cocoa
import NEKit
import CocoaLumberjackSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var httpProxy: GCDHTTPProxyServer?
    var socks5Proxy: GCDSOCKS5ProxyServer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        DDLog.removeAllLoggers()
        DDLog.add(DDTTYLogger.sharedInstance(), with: .info)

        ObserverFactory.currentFactory = DebugObserverFactory()

        httpProxy = GCDHTTPProxyServer(address: nil, port: NEKit.Port(port: UInt16(16881)))
        try! httpProxy!.start()

        let port = NEKit.Port(port: UInt16(16881+1))
        socks5Proxy = GCDSOCKS5ProxyServer(address: nil, port: port)
        // swiftlint:disable force_try
        try! socks5Proxy!.start()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        httpProxy?.stop()
        socks5Proxy?.stop()
    }

}
