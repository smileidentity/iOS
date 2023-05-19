import UIKit
import SmileIdentity

@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions
                     launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window?.overrideUserInterfaceStyle = .light
        do {
            let config = try Config(url: Constant.configUrl)
            SmileIdentity.initialize(config: config)
        } catch {
            print(error.localizedDescription)
        }
        return true
    }
}
