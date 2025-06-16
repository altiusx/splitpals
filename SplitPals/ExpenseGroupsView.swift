//
//  ExpenseGroupsView.swift
//  SplitPals
//
//  Created by Chris Choong on 16/6/25.
//
import SwiftUI
import CoreData

struct ExpenseGroupsView: View {
    @FetchRequest(entity: ExpenseGroup.entity(), sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)]
    ) var groups: FetchedResults<ExpenseGroup>
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showAddGroup: Bool = false
    @State private var newGroupName: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    NavigationLink(destination: ExpenseListView(group: group)) {
                        Text(group.name ?? "Uncategorised")
                            .font(.headline)
                    }
                }
                .onDelete(perform: deleteGroups)
            }
            .navigationTitle("Expense Groups")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showAddGroup = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddGroup) {
                NavigationView {
                    Form {
                        TextField("Group Name", text: $newGroupName)
                    }
                    .navigationTitle(Text("Add Group"))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                addGroup()
                                showAddGroup = false
                            }
                            .disabled(newGroupName.isEmpty)
                        }
                            
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddGroup = false }
                        }
                    }
                }
            }
            .onAppear {
                setOrphanExpensesToUncategorised(context: viewContext)
            }
        }
    }
    
    func addGroup() {
        withAnimation {
            let newGroup = ExpenseGroup(context: viewContext)
            newGroup.name = newGroupName
            newGroup.createdAt = Date()
            do {
                try viewContext.save()
            } catch {
                // error handling
            }
            newGroupName = ""
        }
    }
    
    func deleteGroups(at offsets: IndexSet) {
        for idx in offsets { viewContext.delete(groups[idx])}
        do {
            try viewContext.save()
        } catch {
            // error handling
        }
    }
    
    func setOrphanExpensesToUncategorised(context: NSManagedObjectContext) {
        // create uncategorised expenses group
        let groupFetch: NSFetchRequest<ExpenseGroup> = ExpenseGroup.fetchRequest()
        
        groupFetch.predicate = NSPredicate(format: "name == %@", "Uncategorised")
        
        groupFetch.fetchLimit = 1
        
        let group: ExpenseGroup
        if let found = try? context.fetch(groupFetch), let existing = found.first {
            group = existing
        } else {
            group = ExpenseGroup(context: context)
            group.name = "Uncategorised"
            group.createdAt = Date()
        }
        
        // find expenses with no group and save in uncategorised
        let expenseFetch: NSFetchRequest<Expense> = Expense.fetchRequest()
        expenseFetch.predicate = NSPredicate(format: "expensegroup == nil")
        
        if let orphanExpenses = try? context.fetch(expenseFetch), !orphanExpenses.isEmpty {
            for expense in orphanExpenses {
                expense.expensegroup = group
            }
            try? context.save()
        }
    }
    
}
