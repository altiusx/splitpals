//
//  FriendsListView.swift
//  SplitPals
//
//  Created by Chris Choong
//

import SwiftUI
import CoreData

/// Manages the user's friends. Pushed from Settings, so it provides no
/// navigation stack of its own.
///
/// All friends are currently "local" — created by hand and stored on this
/// device. When Sign in with Apple lands, friends with Apple accounts will
/// link here and see shared groups from their own devices.
struct FriendsListView: View {
    @Environment(\.managedObjectContext) var viewContext

    @FetchRequest(
        entity: Person.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        predicate: NSPredicate(format: "isCurrentUser == NO")
    ) var friends: FetchedResults<Person>

    @StateObject private var errorHandler = ErrorHandler()
    @State private var activeSheet: FriendSheet?

    private var personManager: PersonManager {
        PersonManager(context: viewContext)
    }

    var body: some View {
        List {
            Section {
                if friends.isEmpty {
                    ContentUnavailableView(
                        "No Friends Yet",
                        systemImage: "person.2",
                        description: Text("Tap + to add a friend")
                    )
                } else {
                    ForEach(friends) { friend in
                        friendRow(friend)
                    }
                    .onDelete(perform: deleteFriends)
                }
            } footer: {
                Text("Friends are stored on this device. Linking friends by Apple account to share groups is coming soon.")
            }
        }
        .navigationTitle("Friends")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { activeSheet = .addFriend }) {
                    Label("Add Friend", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addFriend:
                AddEditFriend()
                    .environment(\.managedObjectContext, viewContext)
            case .editFriend(let person):
                AddEditFriend(personToEdit: person)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .errorAlert(errorHandler: errorHandler)
    }

    private func friendRow(_ friend: Person) -> some View {
        HStack(spacing: 12) {
            Image(systemName: friend.icon ?? "person.crop.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 36)

            Text(friend.name ?? "Unknown")
                .font(.body)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            activeSheet = .editFriend(friend)
        }
    }

    private func deleteFriends(at offsets: IndexSet) {
        for index in offsets {
            let friend = friends[index]
            do {
                try personManager.deletePerson(friend)
            } catch {
                errorHandler.handleCoreDataError(error, operation: .delete)
            }
        }
    }
}

// MARK: - Sheet Enum

enum FriendSheet: Identifiable {
    case addFriend
    case editFriend(Person)

    var id: String {
        switch self {
        case .addFriend:
            return "addFriend"
        case .editFriend(let person):
            return person.objectID.uriRepresentation().absoluteString
        }
    }
}
