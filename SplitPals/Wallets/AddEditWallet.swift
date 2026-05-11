//
//  AddEditWallet.swift
//  SplitPals
//
//  Created by Chris Choong on 25/6/25.
//
import SwiftUI
import CoreData

struct AddEditWallet: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var errorHandler = ErrorHandler()
    
    private var walletManager: WalletManager {
        WalletManager(context: viewContext)
    }
    
    // Inputs for wallet creation
    @State private var walletName: String = ""
    @State private var selectedGradientName: String = "Sunset"
    @State private var selectedSymbol: String = "iphone"
    
    // editing wallet
    var walletToEdit: Wallet? = nil
    
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
                                title: walletName.isEmpty ? "Wallet" : walletName
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
                    TextField("Wallet Name", text: $walletName)
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
            .navigationTitle(walletToEdit == nil ? "Add Wallet" : "Edit Wallet")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWallet()
                    }
                    .disabled(walletName.isEmpty)
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
    
    init(walletToEdit: Wallet? = nil, onSave: (() -> Void)? = nil) {
        self.walletToEdit = walletToEdit
        self.onSave = onSave
        // when editing, prefill the wallet state
        _walletName = State(initialValue: walletToEdit?.name ?? "")
        _selectedGradientName = State(initialValue: walletToEdit?.gradientName ?? "Sunset")
        _selectedSymbol = State(initialValue: walletToEdit?.icon ?? "iphone")
    }
    
    private func saveWallet() {
        guard !walletName.isEmpty else {
            errorHandler.handle(.invalidInput("Please enter a wallet name"))
            return
        }
        
        withAnimation {
            do {
                if let walletToEdit = walletToEdit {
                    try walletManager.updateWallet(
                        walletToEdit,
                        name: walletName,
                        gradientName: selectedGradientName,
                        icon: selectedSymbol
                    )
                } else {
                    _ = try walletManager.createWallet(
                        name: walletName,
                        gradientName: selectedGradientName,
                        icon: selectedSymbol
                    )
                }
                onSave?()
                dismiss()
            } catch {
                errorHandler.handleCoreDataError(error, operation: "save")
            }
        }
    }
}
