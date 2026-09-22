//
//  dressedApp.swift
//  dressed
//
//  Created by Developer on 9/10/26.
//
// i made it import depop
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
