//
//  ContentView.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//

import SwiftUI

struct ContentView: View {
    
//    @State private var expenses: [(String, Double)] = [
//        ("Starbutts Coffee", 16.80),
//        ("Uber", 33.90),
//        ("Theme Park", 127.70)
//    ]
    
    @FetchRequest(
        entity: Expense.entity(),
        sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending:false)]
    ) var expenses: FetchedResults<Expense>
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showAddExpenseForm: Bool = false
    
    var body: some View {
        NavigationView{
            List{
                ForEach(expenses) { expense in
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
                AddExpenseView()
                    .environment(\.managedObjectContext, viewContext)
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

#Preview {
    ContentView()
}
