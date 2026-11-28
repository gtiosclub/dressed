import FirebaseCore

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

/// Firebase startup configuration shared by the main app entry point.
enum FirebaseBootstrap {
    private static let skipAppCheckArgument = "-skipAppCheck"
    private static let enableAppCheckArgument = "-enableAppCheck"

    static func configureIfNeeded() {
        guard FirebaseApp.app() == nil else { return }
        #if canImport(FirebaseAppCheck)
        installAppCheckProviderFactoryIfNeeded()
        #endif
        FirebaseApp.configure()
        #if canImport(FirebaseAppCheck)
        if !shouldUseAppCheck {
            AppCheck.appCheck().isTokenAutoRefreshEnabled = false
        }
        #endif
    }

    #if canImport(FirebaseAppCheck)
    /// Linked FirebaseAppCheck otherwise falls back to DeviceCheck on first Firestore/Auth call, which
    /// exchanges tokens in Debug and logs App Check 403s. Local-only tokens are used unless opted in.
    private static func installAppCheckProviderFactoryIfNeeded() {
        if shouldUseAppCheck {
            installAppCheckProvider()
        } else {
            AppCheck.setAppCheckProviderFactory(LocalOnlyAppCheckProviderFactory())
        }
    }

    /// Debug builds skip App Check unless `-enableAppCheck` is set so local Firebase work does not require
    /// the App Check API or debug tokens. Release builds install App Attest before `FirebaseApp.configure()`.
    private static var shouldUseAppCheck: Bool {
        if ProcessInfo.processInfo.arguments.contains(skipAppCheckArgument) { return false }
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(enableAppCheckArgument)
        #else
        return true
        #endif
    }

    private static func installAppCheckProvider() {
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        #endif
    }

    private final class LocalOnlyAppCheckProvider: NSObject, AppCheckProvider {
        func getToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
            handler(AppCheckToken(token: "local-only", expirationDate: .distantFuture), nil)
        }
    }

    private final class LocalOnlyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
        func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
            LocalOnlyAppCheckProvider()
        }
    }
    #endif
}