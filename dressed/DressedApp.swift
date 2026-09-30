//
//  DressedApp.swift
//  dressed
//
//  Created by Riva Patel on 9/29/26.
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
