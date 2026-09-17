//
//  dressedApp.swift
//  dressed
//
//  Created by Developer on 9/10/26.
//
//hi
import FirebaseCore
import SwiftUI

@main
struct dressedApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    init() {
            FirebaseApp.configure()
        }
}
