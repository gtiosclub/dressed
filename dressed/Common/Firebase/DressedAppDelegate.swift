import FirebaseCore
import UIKit

/// Configures Firebase as early as UIKit allows so no Auth/Firestore access sees an unconfigured app.
final class DressedAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configureIfNeeded()
        return true
    }
}