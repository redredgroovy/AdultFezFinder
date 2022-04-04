//
//  AdultFezFinderApp.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/19/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import SwiftUI

@main
struct AdultFezFinderApp: App {
    @StateObject var bleController = BLEController()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleController)
        }
    }
}
