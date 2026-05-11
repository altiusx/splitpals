//
//  AddEditReceipt.swift
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
    @StateObject private var errorHandler = ErrorHandler()
    
    // Manager
    private var receiptManager: ReceiptManager {
        ReceiptManager(context: viewContext)
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
            .onAppear {
                if let receipt = receiptToEdit {
                    name = receipt.name ?? ""
                    
                    // Use CurrencyFormatter to convert amount to raw string
                    if let currency = receipt.currency {
                        rawAmount = CurrencyFormatter.convertToRawAmount(receipt.amount, currency: currency)
                    }
                    
                    selectedCurrency = receipt.currency
                    selectedWallet = receipt.wallet
                } else {
                    // Set default wallet
                    if selectedWallet == nil {
                        if let currentWallet = wallet {
                            selectedWallet = currentWallet
                        } else if !wallets.isEmpty {
                            selectedWallet = wallets.first
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
                        saveReceipt()
                    }
                    .disabled(selectedCurrency == nil || Int(rawAmount) == nil || name.isEmpty || rawAmount.isEmpty || selectedWallet == nil)
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
    
    private func saveReceipt() {
        guard let currency = selectedCurrency else {
            errorHandler.handle(.missingCurrency)
            return
        }
        
        guard let wallet = selectedWallet else {
            errorHandler.handle(.missingWallet)
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
            if let existing = receiptToEdit {
                try receiptManager.updateReceipt(
                    existing,
                    name: name,
                    amount: amount,
                    currency: currency,
                    wallet: wallet
                )
            } else {
                _ = try receiptManager.createReceipt(
                    name: name,
                    amount: amount,
                    currency: currency,
                    wallet: wallet
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
