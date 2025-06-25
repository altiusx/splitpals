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
                        HStack {
                            Spacer()
                            AppCardView(
                                icon: selectedSymbol,
                                gradientColors: availableGradients.first(where: { $0.name == selectedGradientName })?.colors ?? [Color.blue, Color.purple],
                                title: walletName.isEmpty ? "Wallet" : walletName
                            )
                            .frame(width: geo.size.width * 0.6, height: geo.size.width * 0.6 / 1.4)
                            Spacer()
                        }
                    }
                    .frame(height: UIScreen.main.bounds.width * 0.6 / 1.4)
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
                        onSave?()
                    }
                    .disabled(walletName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
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
        withAnimation {
            let wallet: Wallet
            if let walletToEdit = walletToEdit {
                wallet = walletToEdit
            } else {
                wallet = Wallet(context: viewContext)
                wallet.createdAt = Date()
            }
            wallet.name = walletName
            wallet.gradientName = selectedGradientName
            wallet.icon = selectedSymbol

            do {
                try viewContext.save()
                onSave?()
                dismiss()
            } catch {
                // error handling
            }
        }
    }
}
