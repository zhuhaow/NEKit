import Cocoa
import NEKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let config = Configuration()
        let filepath = (NSHomeDirectory() as NSString).stringByAppendingPathComponent(".NEKit_demo.yaml")
        if config.load(fromConfigFile: filepath) {
            RuleManager.currentManager = config.ruleManager
            ProxyServer.mainProxy = GCDSOCKS5ProxyServer(address: IPv4Address(fromString: "127.0.0.1"), port: Port(port: UInt16(config.proxyPort!)))
            // swiftlint:disable force_try
            try! ProxyServer.mainProxy.start()
        } else {
            NSLog("Failed to load config file.")
            exit(1)
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        ProxyServer.mainProxy.stop()
    }


}
