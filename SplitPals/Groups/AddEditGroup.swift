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

    // Inputs for group creation
    @State private var groupName: String = ""
    @State private var selectedGradientName: String = "Sunset"
    @State private var selectedSymbol: String = "iphone"

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

    private func saveGroup() {
        guard !groupName.isEmpty else {
            errorHandler.handle(.invalidInput("Please enter a group name"))
            return
        }

        withAnimation {
            do {
                if let groupToEdit = groupToEdit {
                    try groupManager.updateGroup(
                        groupToEdit,
                        name: groupName,
                        gradientName: selectedGradientName,
                        icon: selectedSymbol
                    )
                } else {
                    let group = try groupManager.createGroup(
                        name: groupName,
                        gradientName: selectedGradientName,
                        icon: selectedSymbol
                    )
                    let personManager = PersonManager(context: viewContext)
                    if let currentUser = try personManager.fetchCurrentUser() {
                        group.addToMembers(currentUser)
                        try viewContext.save()
                    }
                }
                onSave?()
                dismiss()
            } catch {
                errorHandler.handleCoreDataError(error, operation: "save")
            }
        }
    }
}
