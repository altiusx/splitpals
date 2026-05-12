//
//  FriendsView.swift
//  SplitPals
//
//  Created by Chris Choong
//

import SwiftUI
import CoreData

struct FriendsView: View {
    @Environment(\.managedObjectContext) var viewContext
    
    @FetchRequest(
        entity: Person.entity(),
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)],
        predicate: NSPredicate(format: "isCurrentUser == NO")
    ) var friends: FetchedResults<Person>
    
    @FetchRequest(
        entity: Person.entity(),
        sortDescriptors: [],
        predicate: NSPredicate(format: "isCurrentUser == YES")
    ) var currentUserResults: FetchedResults<Person>
    
    @StateObject private var errorHandler = ErrorHandler()
    @State private var activeSheet: FriendSheet?
    
    private var personManager: PersonManager {
        PersonManager(context: viewContext)
    }
    
    var body: some View {
        NavigationStack {
            List {
                if let currentUser = currentUserResults.first {
                    Section("Me") {
                        HStack(spacing: 12) {
                            Image(systemName: currentUser.icon ?? "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .frame(width: 36)
                            
                            Text(currentUser.name ?? "Me")
                                .font(.headline)
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            activeSheet = .editFriend(currentUser)
                        }
                    }
                }
                
                Section("Friends") {
                    if friends.isEmpty {
                        ContentUnavailableView(
                            "No Friends Yet",
                            systemImage: "person.2",
                            description: Text("Tap + to add a friend")
                        )
                    } else {
                        ForEach(friends) { friend in
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
                        .onDelete(perform: deleteFriends)
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .automatic) {
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
    }
    
    private func deleteFriends(at offsets: IndexSet) {
        for index in offsets {
            let friend = friends[index]
            do {
                try personManager.deletePerson(friend)
            } catch {
                errorHandler.handleCoreDataError(error, operation: "delete")
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
