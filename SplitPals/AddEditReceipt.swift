//
//  AddExpenseView.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//

import SwiftUI
import CoreData
import UIKit

struct AddEditReceipt: View {
    
    var receiptToEdit: Receipt? = nil
    var wallet: Wallet?
    var onSave: (() -> Void)? = nil
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // edit wallet to put receipt in
    @FetchRequest(entity: Wallet.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Wallet.name, ascending: true)]
    ) var wallets: FetchedResults<Wallet>
    
    @State private var selectedWallet: Wallet? = nil
 
    // currencies and value
    @FetchRequest(
        entity: Currency.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Currency.name, ascending: true)]
    ) var currencies: FetchedResults<Currency>
    
    @State private var name: String = ""
    @State private var rawAmount: String = ""
    @State private var selectedCurrency: Currency? = nil
    @FocusState private var isAmountFieldFocused: Bool
    
    // Error Handling
    @State private var showErrorAlert = false
    @State private var userFriendlyErrorMessage = ""
        
    var amount: Double {
        Double(Int(rawAmount) ?? 0) / 100.0
    }
    
    var formattedAmount: String {
        guard let currency = selectedCurrency else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        formatter.currencySymbol = currency.symbol
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency.symbol ?? "$")0.00"
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
                    .onAppear{
                        if selectedCurrency == nil, !currencies.isEmpty {
                            // to include coreLocation to determine currency
                            selectedCurrency = currencies.first(where: {$0.code == "SGD"}) ?? currencies.first
                        }
                    }
                    // in case async fetch or changes in core data
//                    .onChange(of: currencies) { newCurrencies in
//                        if selectedCurrency == nil, let first = newCurrencies.first {
//                            selectedCurrency = newCurrencies.first(where: {$0.code == "SGD"}) ?? first
//                        }
//                    }
                }
                Section(header: Text("Wallet")) {
                    Picker("Wallet", selection: $selectedWallet) {
                        if selectedWallet == nil {
                            Text("Select a wallet").tag(nil as Wallet?)
                        }
                        ForEach(wallets, id: \.self) { wallet in
                            Text(wallet.name ?? "Unnamed Wallet").tag(wallet as Wallet?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(receiptToEdit == nil ? "Add Receipt" : "Edit Receipt")
            .onAppear{
                if let receipt = receiptToEdit {
                    name = receipt.name ?? ""
                    rawAmount = String(Int((receipt.amount * 100).rounded()))
                    selectedCurrency = receipt.currency
                    selectedWallet = receipt.wallet
                } else {
                    if selectedCurrency == nil, !currencies.isEmpty {
                        selectedCurrency = currencies.first(where: { $0.code == "SGD" }) ?? currencies.first
                    }
                    if selectedWallet == nil, !wallets.isEmpty {
                        selectedWallet = wallets.first
                    }
                }
            }
            .toolbar{
                ToolbarItem(placement: .confirmationAction){
                    Button("Save") {
                        saveReceipt()
                        dismiss()
                    }
                    .disabled(selectedCurrency == nil || Int(rawAmount) == nil || name.isEmpty || rawAmount.isEmpty || selectedWallet == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Oops!", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message : {
                Text(userFriendlyErrorMessage)
            }
        }
    }
    
    private func saveReceipt() {
        guard let currency = selectedCurrency,
              let wallet = selectedWallet,
              !name.isEmpty,
              let _ = Int(rawAmount) else {
            userFriendlyErrorMessage = "Please fill in all fields correctly."
            showErrorAlert = true
            return
        }

        let receipt: Receipt
        if let existing = receiptToEdit {
            receipt = existing
        } else {
            receipt = Receipt(context: viewContext)
            receipt.timestamp = Date()
        }

        receipt.name = name
        receipt.amount = amount
        receipt.currency = currency
        receipt.wallet = wallet

        do {
            try viewContext.save()
            onSave?()
            dismiss()
        } catch {
            userFriendlyErrorMessage = "Sorry, something went wrong. Please try again."
            showErrorAlert = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
}
