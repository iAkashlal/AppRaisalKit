//
//  AppRaisalKit_SampleApp.swift
//  AppRaisalKit Sample
//
//  Created by Akashlal Bathe on 09/03/26.
//

import SwiftUI

@main
struct AppRaisalKit_SampleApp: App {
    @StateObject private var appRatingManager = AppRatingManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appRatingManager)
        }
    }
}
