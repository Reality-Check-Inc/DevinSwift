//
//  DevinSwiftAppApp.swift
//  DevinSwiftApp
//
//  Created by David N. Junod on 3/25/25.
//

import SwiftUI

@main
struct DevinSwiftAppApp: App {
    init() {
        // Setup default values if needed
        if UserDefaults.standard.string(forKey: "openAIApiKey") == nil {
            UserDefaults.standard.set("", forKey: "openAIApiKey")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
