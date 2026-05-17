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

                FriendsView()
                    .tabItem {
                        Label("Friends", systemImage: "person.2")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
        }
    }
}
