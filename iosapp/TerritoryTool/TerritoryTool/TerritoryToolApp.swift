//
//  TerritoryToolApp.swift
//  TerritoryTool
//
//  Created by Jared Trapiello on 3/12/25.
//

import SwiftUI

@main
struct TerritoryToolApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Make sure a background refresh is queued from a cold launch too.
                    TokenRefreshScheduler.scheduleNext()
                }
        }
        // Runs ~every 5 days while the app is backgrounded to keep the session alive.
        .backgroundTask(.appRefresh(TokenRefreshScheduler.taskIdentifier)) {
            await TokenRefreshScheduler.runRefresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                TokenRefreshScheduler.scheduleNext()
            }
        }
    }
}
