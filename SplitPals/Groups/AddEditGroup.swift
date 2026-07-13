//
//  AddEditGroup.swift
//  SplitPals
//
//  Created by Chris Choong on 25/6/25.
//
import SwiftUI
import CoreData

struct AddEditGroup: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var errorHandler = ErrorHandler()

    private var groupManager: GroupManager {
        GroupManager(context: viewContext)
    }

    @FetchRequest(
        entity: Person.entity(),
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
    ) var allPersons: FetchedResults<Person>

    // Inputs for group creation
    @State private var groupName: String = ""
    @State private var selectedGradientName: String = "Sunset"
    @State private var selectedSymbol: String = "iphone"
    @State private var selectedMembers: Set<Person> = []

    // editing group
    var groupToEdit: ExpenseGroup? = nil

    // callback for parent to refresh UI
    var onSave: (() -> Void)?

    let availableGradients: [AppCardGradient] = cardGradients

    var body: some View {
        NavigationView {
            Form {
                Section {
                    GeometryReader { geo in
                        VStack {
                            AppCardView(
                                icon: selectedSymbol,
                                gradientColors: availableGradients.first(where: { $0.name == selectedGradientName })?.colors ?? [Color.blue, Color.purple],
                                title: groupName.isEmpty ? "Group" : groupName
                            )
                            .frame(width: geo.size.width * 0.7)
                            .aspectRatio(1.4, contentMode: .fit)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                Section(header: Text("Name")) {
                    TextField("Group Name", text: $groupName)
                }
                Section {
                    ForEach(allPersons, id: \.self) { person in
                        memberRow(person)
                    }
                } header: {
                    Text("Members")
                } footer: {
                    Text("Expenses can be split between the members of this group.")
                }
                Section(header: Text("Color")) {
                    GradientColorPicker(
                        selectedGradientName: $selectedGradientName,
                        gradients: availableGradients
                    )
                }
                Section(header: Text("Icon")) {
                    IconPicker(
                        selectedSymbol: $selectedSymbol,
                        categories: sfSymbolCategories
                    )
                }
            }
            .navigationTitle(groupToEdit == nil ? "Add Group" : "Edit Group")
            .onAppear(perform: configureMembers)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGroup()
                    }
                    .disabled(groupName.isEmpty)
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

    init(groupToEdit: ExpenseGroup? = nil, onSave: (() -> Void)? = nil) {
        self.groupToEdit = groupToEdit
        self.onSave = onSave
        // when editing, prefill the group state
        _groupName = State(initialValue: groupToEdit?.name ?? "")
        _selectedGradientName = State(initialValue: groupToEdit?.gradientName ?? "Sunset")
        _selectedSymbol = State(initialValue: groupToEdit?.icon ?? "iphone")
    }

    @ViewBuilder
    private func memberRow(_ person: Person) -> some View {
        let isSelected = selectedMembers.contains(person)

        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

            Image(systemName: person.icon ?? "person.crop.circle")
                .foregroundStyle(.secondary)

            Text(person.isCurrentUser ? "\(person.name ?? "Me") (Me)" : (person.name ?? "Unknown"))

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // The current user is always part of their own groups.
            guard !person.isCurrentUser else { return }
            if isSelected {
                selectedMembers.remove(person)
            } else {
                selectedMembers.insert(person)
            }
        }
    }

    private func configureMembers() {
        if let groupToEdit {
            selectedMembers = Set(groupToEdit.membersArray)
        }
        if let currentUser = try? AuthService.shared.currentUser(in: viewContext) {
            selectedMembers.insert(currentUser)
        }
    }

    private func saveGroup() {
        guard !groupName.isEmpty else {
            errorHandler.handle(.invalidInput("Please enter a group name"))
            return
        }

        withAnimation {
            do {
                let group: ExpenseGroup
                if let groupToEdit = groupToEdit {
                    try groupManager.updateGroup(
                        groupToEdit,
                        name: groupName,
                        gradientName: selectedGradientName,
                        icon: selectedSymbol
                    )
                    group = groupToEdit
                } else {
                    group = try groupManager.createGroup(
                        name: groupName,
                        gradientName: selectedGradientName,
                        icon: selectedSymbol
                    )
                }

                var members = selectedMembers
                if let currentUser = try AuthService.shared.currentUser(in: viewContext) {
                    members.insert(currentUser)
                }
                try groupManager.updateMembers(group, members: Array(members))
                onSave?()
                dismiss()
            } catch {
                errorHandler.handleCoreDataError(error, operation: "save")
            }
        }
    }
}
