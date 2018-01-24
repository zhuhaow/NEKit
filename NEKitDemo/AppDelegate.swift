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
        DDLog.add(DDTTYLogger.sharedInstance, with: .info)

        ObserverFactory.currentFactory = DebugObserverFactory()

        let config = Configuration()
        let filepath = (NSHomeDirectory() as NSString).appendingPathComponent(".NEKit_demo.yaml")
        // swiftlint:disable force_try
        do {
            try config.load(fromConfigFile: filepath)
        } catch let error {
            DDLogError("\(error)")
        }
        RuleManager.currentManager = config.ruleManager
        httpProxy = GCDHTTPProxyServer(address: nil, port: NEKit.Port(port: UInt16(config.proxyPort!)))
        // swiftlint:disable force_try
        try! httpProxy!.start()

        let port = NEKit.Port(port: UInt16(config.proxyPort!+1))
        socks5Proxy = GCDSOCKS5ProxyServer(address: nil, port: port)
        // swiftlint:disable force_try
        try! socks5Proxy!.start()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        httpProxy?.stop()
        socks5Proxy?.stop()
    }

}
