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
    
    let avatarIcons = [
        "person.crop.circle.fill",
        "person.fill",
        "figure.stand",
        "face.smiling.inverse",
        "star.circle.fill",
        "heart.circle.fill",
        "bolt.circle.fill",
        "flame.circle.fill",
        "leaf.circle.fill",
        "moon.circle.fill",
        "sun.max.circle.fill",
        "sparkles"
    ]
    
    var body: some View {
        NavigationView {
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
                        ForEach(avatarIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 48, height: 48)
                                .background(
                                    Circle()
                                        .fill(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(selectedIcon == icon ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(personToEdit == nil ? "Add Friend" : "Edit Friend")
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
            errorHandler.handleCoreDataError(error, operation: "save")
        }
    }
}
