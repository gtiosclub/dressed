import FirebaseCore
import FirebaseFirestore
import SwiftUI

@main
struct DressedApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-mockSession") {
                ContentView(session: SessionViewModel(service: PreviewSessionService(userId: nil)))
            } else {
                SavePostTestView() // TEMP
            }
            #else
            ContentView(session: SessionViewModel(service: FirebaseSessionService()))
            #endif
        }
    }
    init() {
        FirebaseApp.configure()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-useEmulator") {
            let settings = Firestore.firestore().settings
            settings.host = "127.0.0.1:8080"
            settings.isSSLEnabled = false
            settings.cacheSettings = MemoryCacheSettings()
            Firestore.firestore().settings = settings
        }
        #endif
    }
}
