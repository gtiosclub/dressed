import SwiftUI

// Independent diagnostics using the same recognition code as Dressed.
// This target has no Firebase initialization, app-group entitlement or closet UI.
@main
struct RecognitionLabApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack { RecognitionLabView(showsImportSettings: false) }
        }
    }
}
