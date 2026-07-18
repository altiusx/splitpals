//
//  ContentView.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) var viewContext

    @FetchRequest(
        entity: Person.entity(),
        sortDescriptors: [],
        predicate: NSPredicate(format: "isCurrentUser == YES")
    ) var currentUserResults: FetchedResults<Person>

    @State private var hasCompletedOnboarding = false

    var body: some View {
        if currentUserResults.isEmpty && !hasCompletedOnboarding {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        } else {
            TabView {
                GroupView()
                    .tabItem {
                        Label("Groups", systemImage: "rectangle.stack")
                    }

                MyExpensesView()
                    .tabItem {
                        Label("Expenses", systemImage: "receipt")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            // On iPad and Mac the tabs become a sidebar, freeing the wide
            // leading edge; iPhone keeps the regular tab bar.
            .tabViewStyle(.sidebarAdaptable)
        }
    }
}
