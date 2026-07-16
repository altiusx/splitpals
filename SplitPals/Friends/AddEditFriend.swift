//
//  AddEditFriend.swift
//  SplitPals
//
//  Created by Chris Choong
//

import SwiftUI
import CoreData

struct AddEditFriend: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var errorHandler = ErrorHandler()
    
    private var personManager: PersonManager {
        PersonManager(context: viewContext)
    }
    
    @State private var friendName: String = ""
    @State private var selectedIcon: String = "person.crop.circle"
    
    var personToEdit: Person? = nil

    private var navigationTitle: String {
        guard let personToEdit else { return "Add Friend" }
        return personToEdit.isCurrentUser ? "Edit Profile" : "Edit Friend"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Image(systemName: selectedIcon)
                            .font(.system(size: 60))
                            .foregroundStyle(.tint)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("Name")) {
                    TextField("Name", text: $friendName)
                }
                
                Section(header: Text("Avatar")) {
                    AvatarPicker(selectedIcon: $selectedIcon)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveFriend()
                    }
                    .disabled(friendName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .errorAlert(errorHandler: errorHandler)
        }
    }
    
    init(personToEdit: Person? = nil) {
        self.personToEdit = personToEdit
        _friendName = State(initialValue: personToEdit?.name ?? "")
        _selectedIcon = State(initialValue: personToEdit?.icon ?? "person.crop.circle")
    }
    
    private func saveFriend() {
        let trimmedName = friendName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorHandler.handle(.invalidInput("Please enter a name"))
            return
        }
        
        do {
            if let personToEdit = personToEdit {
                try personManager.updatePerson(
                    personToEdit,
                    name: trimmedName,
                    icon: selectedIcon
                )
            } else {
                _ = try personManager.createPerson(
                    name: trimmedName,
                    icon: selectedIcon
                )
            }
            dismiss()
        } catch {
            errorHandler.handleCoreDataError(error, operation: .save)
        }
    }
}
