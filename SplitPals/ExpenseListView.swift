//
//  ExpenseListView.swift
//  SplitPals
//
//  Created by Chris Choong on 16/6/25.
//
import SwiftUI

struct ExpenseListView: View {
    @ObservedObject var group: ExpenseGroup
    
    @FetchRequest(
        entity: Expense.entity(),
        sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending:false)]
    ) var expenses: FetchedResults<Expense>

    @Environment(\.managedObjectContext) private var viewContext

    @State private var showAddExpenseForm: Bool = false

    var body: some View {
        NavigationView{
            List{
                ForEach(group.expensesArray, id: \.self) { expense in
                    ExpenseRow(name: expense.name ?? "", amount: expense.amount)
                }
                .onDelete(perform: deleteExpense)
            }
            .navigationTitle("Expenses")
            .toolbar{
                EditButton()
                Button(action: {
                    showAddExpenseForm = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddExpenseForm) {
                AddExpenseView(group: group)
            }
        }
    }

    func deleteExpense(at offsets: IndexSet) {
        for index in offsets {
            let expense = expenses[index]
            viewContext.delete(expense)
        }
        do { try viewContext.save() } catch {
            // error handling
        }
    }
}
