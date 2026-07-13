//
//  GroupView.swift
//  SplitPals
//
//  Created by Chris Choong on 16/6/25.
//
import SwiftUI
import CoreData

struct GroupView: View {
    @FetchRequest(entity: ExpenseGroup.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \ExpenseGroup.createdAt, ascending: true)]
    ) var groups: FetchedResults<ExpenseGroup>

    @FetchRequest(entity: Expense.entity(), sortDescriptors: [], predicate: NSPredicate(format: "group == nil")
    ) var uncategorisedExpenses: FetchedResults<Expense>

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var errorHandler = ErrorHandler()

    private var groupManager: GroupManager {
        GroupManager(context: viewContext)
    }

    // warning prompts when deleting group
    @State private var groupToDelete: ExpenseGroup?
    @State private var showDeletePrompt: Bool = false

    /// The legacy fallback group is hidden while it has no expenses.
    private static let uncategorisedGroupName = "Uncategorised Expenses"

    private var filteredGroups: [ExpenseGroup] {
        groups.filter { group in
            group.name != Self.uncategorisedGroupName || !group.expensesArray.isEmpty
        }
    }

    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    enum ActiveSheet: Identifiable {
        case addGroup
        case editGroup(ExpenseGroup)
        case addExpense(ExpenseGroup)

        var id: String {
            switch self {
            case .addGroup: return "addGroup"
            case .editGroup(let group): return "editGroup_\(group.objectID.uriRepresentation().absoluteString)"
            case .addExpense(let group): return "addExpense_\(group.objectID.uriRepresentation().absoluteString)"
            }
        }
    }

    @State private var activeSheet: ActiveSheet?

    var body: some View {
        NavigationStack {
            ScrollView {
                groupsGrid()
                    .padding()
            }
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    addGroupButton
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addGroup:
                    AddEditGroup {
                        activeSheet = nil
                    }
                    .environment(\.managedObjectContext, viewContext)
                case .editGroup(let group):
                    AddEditGroup(groupToEdit: group) {
                        activeSheet = nil
                    }
                    .environment(\.managedObjectContext, viewContext)
                case .addExpense(let group):
                    AddEditExpense(group: group)
                }
            }
            .alert("Delete Group?", isPresented: $showDeletePrompt, presenting: groupToDelete) { group in
                Button("Delete", role: .destructive) {
                    deleteGroup(group)
                }
                Button("Cancel", role: .cancel) {}
            } message: { group in
                Text("This will delete \(group.name ?? "group") and all its expenses")
            }
        }
        .errorAlert(errorHandler: errorHandler)
    }

    private var addGroupButton: some View {
        Button(action: { activeSheet = .addGroup }) {
            Label("Add Group", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
    }

    @ViewBuilder
    private func groupsGrid() -> some View {
        LazyVGrid(columns: gridColumns, spacing: 20) {
            ForEach(filteredGroups) { group in
                NavigationLink(destination: ExpenseListView(group: group)) {
                    AppCardView(
                        icon: group.icon ?? "creditcard",
                        gradientColors: colorForGroup(group),
                        title: group.name ?? "Uncategorised Expenses",
                        memberInitials: group.membersArray.map(\.initial),
                        onEdit: { activeSheet = .editGroup(group) },
                        onAddExpense: { activeSheet = .addExpense(group) },
                        onDelete: { groupToDelete = group; showDeletePrompt = true }
                    )
                    .aspectRatio(1.4, contentMode: .fit)
                }
            }
        }
    }

    private func deleteGroup(_ group: ExpenseGroup) {
        do {
            try groupManager.deleteGroup(group)
        } catch {
            errorHandler.handleCoreDataError(error, operation: .delete)
        }
    }

    private func colorForGroup(_ group: ExpenseGroup) -> [Color] {
        AppCardGradient.colors(named: group.gradientName)
    }
}
