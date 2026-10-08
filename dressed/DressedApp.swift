//
//  DressedApp.swift
//  dressed
//
//  Created by Developer on 9/10/26.
//
import FirebaseCore
import SwiftUI

// initialization of the app

//@main
//struct DressedApp: App {
//    var body: some Scene {
//        WindowGroup {
//            #if DEBUG
//            if ProcessInfo.processInfo.arguments.contains("-mockSession") {
//                ContentView(session: SessionViewModel(service: PreviewSessionService(userId: nil)))
//            } else {
//                ContentView(session: SessionViewModel(service: FirebaseSessionService()))
//            }
//            #else
//            ContentView(session: SessionViewModel(service: FirebaseSessionService()))
//            #endif
//        }
//    }
//    init() {
//        FirebaseApp.configure()
//    }
//}

@main
struct DressedApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-mockSession") {
                ContentView(session: SessionViewModel(service: PreviewSessionService(userId: nil)))
            } else {
                SavePostTestView()   // TEMP: testing savePost 
                // ContentView(session: SessionViewModel(service: FirebaseSessionService()))
            }
            #else
            ContentView(session: SessionViewModel(service: FirebaseSessionService()))
            #endif
        }
    }
    init() {
        FirebaseApp.configure()
    }
}
