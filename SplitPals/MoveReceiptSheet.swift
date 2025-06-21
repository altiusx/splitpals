//
//  MoveExpenseSheet.swift
//  SplitPals
//
//  Created by Chris Choong on 16/6/25.
//
import SwiftUI
import CoreData

struct MoveReceiptSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @FetchRequest(
        entity: Wallet.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Wallet.name, ascending: true)]
    ) var wallets: FetchedResults<Wallet>

    var receipt: Receipt
    var currentWallet: Wallet

    @State private var selectedWallet: Wallet?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Move to Wallet", selection: $selectedWallet) {
                    ForEach(wallets, id: \.self) { wallet in
                        // Hide the current group as a move target
                        if wallet != currentWallet {
                            Text(wallet.name ?? "Unnamed").tag(wallet as Wallet?)
                        }
                    }
                }
            }
            .navigationTitle("Move Receipt")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        if let newWallet = selectedWallet {
                            receipt.wallet = newWallet
                            try? viewContext.save()
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            dismiss()
                        }
                    }
                    .disabled(selectedWallet == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                selectedWallet = nil
            }
        }
    }
}
