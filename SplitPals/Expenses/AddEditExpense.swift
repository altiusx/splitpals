//
//  AddEditExpense.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//

import SwiftUI
import CoreData
import UIKit

struct AddEditExpense: View {

    var expenseToEdit: Expense? = nil
    var group: ExpenseGroup?
    var onSave: (() -> Void)? = nil

    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(entity: ExpenseGroup.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \ExpenseGroup.name, ascending: true)]
    ) var groups: FetchedResults<ExpenseGroup>

    @State private var selectedGroup: ExpenseGroup? = nil

    // currencies and value
    @FetchRequest(
        entity: Currency.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Currency.name, ascending: true)]
    ) var currencies: FetchedResults<Currency>

    @State private var name: String = ""
    @State private var rawAmount: String = ""
    @State private var selectedCurrency: Currency? = nil
    @FocusState private var isAmountFieldFocused: Bool
    @State private var shouldClearOnInput: Bool = false

    // Error Handling
    @StateObject private var errorHandler = ErrorHandler()

    // Manager
    private var expenseManager: ExpenseManager {
        ExpenseManager(context: viewContext)
    }

    var fractionDigits: Int {
        guard let currency = selectedCurrency, let code = currency.code else { return 2 }
        return CurrencyFormatter.fractionDigits(for: code)
    }

    var amount: Double {
        let divisor = pow(10.0, Double(fractionDigits))
        return (Double(Int(rawAmount) ?? 0)) / divisor
    }

    var formattedAmount: String {
        guard let currency = selectedCurrency else { return "$0.00" }
        return CurrencyFormatter.format(amount: amount, currency: currency)
    }

    var body: some View {
        NavigationView{
            Form{
                Section(header: Text("Details")){
                    TextField("Description", text: $name)

                    ZStack(alignment: .leading) {
                        // show the formatted amount as text
                        Text(formattedAmount)
                            .font(.title2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isAmountFieldFocused = true
                            }
                        // hidden textfield that receives user input
                        TextField("", text: $rawAmount)
                            .keyboardType(.numberPad)
                            .focused($isAmountFieldFocused)
                            .opacity(0)
                            .allowsHitTesting(false)
                            .onChange(of: rawAmount) {
                                if shouldClearOnInput {
                                    let newDigit = rawAmount.filter { $0.isNumber }.suffix(1)
                                    rawAmount = String(newDigit)
                                    shouldClearOnInput = false
                                    return
                                }
                                let filtered = rawAmount.filter {$0.isNumber}
                                if filtered != rawAmount {
                                    rawAmount = filtered
                                }
                            }
                    }
                }
                Section(header: Text("Currency")) {
                    Picker("Currency", selection: $selectedCurrency) {
                        if selectedCurrency == nil {
                            Text("Select a currency").tag(nil as Currency?)
                        }
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency.name ?? "").tag(currency as Currency?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section(header: Text("Group")) {
                    Picker("Group", selection: $selectedGroup) {
                        if selectedGroup == nil {
                            Text("Select a group").tag(nil as ExpenseGroup?)
                        }
                        ForEach(groups, id: \.self) { group in
                            Text(group.name ?? "Unnamed Group").tag(group as ExpenseGroup?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(expenseToEdit == nil ? "Add Expense" : "Edit Expense")
            .onAppear {
                if let expense = expenseToEdit {
                    name = expense.name ?? ""

                    // Use CurrencyFormatter to convert amount to raw string
                    if let currency = expense.currency {
                        rawAmount = CurrencyFormatter.convertToRawAmount(expense.amount, currency: currency)
                    }

                    selectedCurrency = expense.currency
                    selectedGroup = expense.group
                    shouldClearOnInput = true
                } else {
                    // Set default group
                    if selectedGroup == nil {
                        if let currentGroup = group {
                            selectedGroup = currentGroup
                        } else if !groups.isEmpty {
                            selectedGroup = groups.first
                        }
                    }

                    // Set default currency based on user's locale
                    if selectedCurrency == nil, !currencies.isEmpty {
                        let defaultCode = CurrencyFormatter.defaultCurrencyCode()
                        selectedCurrency = currencies.first(where: { $0.code == defaultCode }) ?? currencies.first
                    }
                }
            }
            .toolbar{
                ToolbarItem(placement: .confirmationAction){
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(selectedCurrency == nil || Int(rawAmount) == nil || name.isEmpty || rawAmount.isEmpty || selectedGroup == nil)
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

    private func saveExpense() {
        guard let currency = selectedCurrency else {
            errorHandler.handle(.missingCurrency)
            return
        }

        guard let group = selectedGroup else {
            errorHandler.handle(.missingGroup)
            return
        }

        guard !name.isEmpty else {
            errorHandler.handle(.invalidInput("Please enter a description"))
            return
        }

        guard !rawAmount.isEmpty, Int(rawAmount) != nil else {
            errorHandler.handle(.invalidInput("Please enter an amount"))
            return
        }

        do {
            if let existing = expenseToEdit {
                try expenseManager.updateExpense(
                    existing,
                    name: name,
                    amount: amount,
                    currency: currency,
                    group: group
                )
            } else {
                _ = try expenseManager.createExpense(
                    name: name,
                    amount: amount,
                    currency: currency,
                    group: group
                )
            }
            onSave?()
            dismiss()
        } catch {
            errorHandler.handleCoreDataError(error, operation: "save")
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}
