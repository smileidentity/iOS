import UIKit
import SmileID
import SwiftUI
import netfox
@available(iOS 14.0, *)
@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions
                     launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black]
        NFX.sharedInstance().start()
        SmileID.initialize()
        window?.rootViewController = UIHostingController(rootView: MainView())
        window?.makeKeyAndVisible()
        return true
    }
}
