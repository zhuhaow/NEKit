import Cocoa
import NEKit
import CocoaLumberjackSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var proxy: GCDHTTPProxyServer?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        DDLog.removeAllLoggers()
        DDLog.addLogger(DDTTYLogger.sharedInstance(), withLevel: .Info)

        ObserverFactory.currentFactory = DebugObserverFactory()

        let config = Configuration()
        let filepath = (NSHomeDirectory() as NSString).stringByAppendingPathComponent(".NEKit_demo.yaml")
        // swiftlint:disable force_try
        try! config.load(fromConfigFile: filepath)
        RuleManager.currentManager = config.ruleManager
        proxy = GCDHTTPProxyServer(address: IPv4Address(fromString: "127.0.0.1"), port: Port(port: UInt16(config.proxyPort!)))
        // swiftlint:disable force_try
        try! proxy!.start()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        proxy?.stop()
    }


}
