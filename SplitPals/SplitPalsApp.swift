//
//  SplitPalsApp.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//

import SwiftUI

@main
struct SplitPalsApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var exchangeRateService = ExchangeRateService.shared
    @AppStorage("forceDarkMode") private var forceDarkMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(exchangeRateService)
                .preferredColorScheme(forceDarkMode ? .dark : nil)
                .task {
                    await exchangeRateService.fetchRates()
                }
        }
    }
}
