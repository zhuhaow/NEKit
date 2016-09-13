import Cocoa
import NEKit
import CocoaLumberjackSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var httpProxy: GCDHTTPProxyServer?
    var socks5Proxy: GCDSOCKS5ProxyServer?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        DDLog.removeAllLoggers()
        DDLog.addLogger(DDTTYLogger.sharedInstance(), withLevel: .Info)

        ObserverFactory.currentFactory = DebugObserverFactory()

        let config = Configuration()
        let filepath = (NSHomeDirectory() as NSString).stringByAppendingPathComponent(".NEKit_demo.yaml")
        // swiftlint:disable force_try
        try! config.load(fromConfigFile: filepath)
        RuleManager.currentManager = config.ruleManager
        httpProxy = GCDHTTPProxyServer(address: IPv4Address(fromString: "127.0.0.1"), port: Port(port: UInt16(config.proxyPort!)))
        // swiftlint:disable force_try
        try! httpProxy!.start()

        socks5Proxy = GCDSOCKS5ProxyServer(address: IPv4Address(fromString: "127.0.0.1"), port: Port(port: UInt16(config.proxyPort!+1)))
        // swiftlint:disable force_try
        try! socks5Proxy!.start()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        httpProxy?.stop()
        socks5Proxy?.stop()
    }


}
