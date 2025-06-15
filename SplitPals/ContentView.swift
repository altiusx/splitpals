//
//  ContentView.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//

import SwiftUI

struct ContentView: View {
    
    @State private var expenses: [(String, Double)] = [
        ("Starbutts Coffee", 16.80),
        ("Uber", 33.90),
        ("Theme Park", 127.70)
    ]
    
    @State private var showAddExpenseForm: Bool = false
    
    var body: some View {
        NavigationView{
            List{
                ForEach(expenses, id: \.0) { expense in
                    ExpenseRow(name: expense.0, amount: expense.1)
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
                AddExpenseView { name, amount in expenses.append((name, amount))}
            }
        }
    }
    
    func deleteExpense(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
    }
    
}

#Preview {
    ContentView()
}
