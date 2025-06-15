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
    
    var body: some Scene {
        WindowGroup {
            ContentView().environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
