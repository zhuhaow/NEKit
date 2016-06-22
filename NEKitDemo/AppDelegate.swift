import Cocoa
import NEKit
import CocoaLumberjackSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var proxy: GCDSOCKS5ProxyServer!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        DDLog.addLogger(DDTTYLogger.sharedInstance(), withLevel: .All)
        let config = Configuration()
        let filepath = (NSHomeDirectory() as NSString).stringByAppendingPathComponent(".NEKit_demo.yaml")
        if config.load(fromConfigFile: filepath) {
            RuleManager.currentManager = config.ruleManager
            proxy = GCDSOCKS5ProxyServer(address: IPv4Address(fromString: "127.0.0.1"), port: Port(port: UInt16(config.proxyPort!)))
            // swiftlint:disable force_try
            try! proxy.start()
        } else {
            exit(1)
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        proxy.stop()
    }


}
