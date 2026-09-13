//
//  DressedApp.swift
//  dressed
//
//  Created by Developer on 9/10/26.
//
import FirebaseCore
import SwiftUI

// initialization of the app

@main
struct DressedApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    init() {
            FirebaseApp.configure()
        }
}
