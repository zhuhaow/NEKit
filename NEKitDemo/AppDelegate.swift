import Cocoa
import NEKit
import CocoaLumberjackSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var proxy: SOCKS5ProxyServer!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        DDLog.addLogger(DDTTYLogger.sharedInstance(), withLevel: .All)
        proxy = SOCKS5ProxyServer(port: 9090)
        proxy.start()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        proxy.stop()
    }


}

