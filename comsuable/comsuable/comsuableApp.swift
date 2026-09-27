//
//  comsuableApp.swift
//  comsuable
//
//  Created by Nash Zhou on 2026/9/16.
//

import SwiftUI

@main
struct comsuableApp: App {
    @StateObject private var store = PassportStore()
    @StateObject private var purchaseManager = PurchaseManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomePartsRootView()
                .environmentObject(store)
                .environmentObject(purchaseManager)
                .task { purchaseManager.configureIfNeeded() }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await purchaseManager.applicationDidBecomeActive() }
        }
    }
}
