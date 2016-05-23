import Cocoa
import NEKit
import CocoaLumberjackSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var proxy: SOCKS5ProxyServer!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        DDLog.addLogger(DDTTYLogger.sharedInstance(), withLevel: .All)
        let config = Configuration()
        let filepath = (NSHomeDirectory() as NSString).stringByAppendingPathComponent(".NEKit_demo.yaml")
        if config.load(fromConfigFile: filepath) {
            RuleManager.currentManager = config.ruleManager
            proxy = SOCKS5ProxyServer(address: "127.0.0.1", port: config.proxyPort!)
            proxy.start()
        } else {
            exit(1)
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        proxy.stop()
    }


}
