//
//  ExpensewalletsView.swift
//  SplitPals
//
//  Created by Chris Choong on 16/6/25.
//
import SwiftUI
import CoreData

struct WalletView: View {
    @FetchRequest(entity: Wallet.entity(), sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)]
    ) var wallets: FetchedResults<Wallet>
    
    @FetchRequest(entity: Receipt.entity(), sortDescriptors: [], predicate: NSPredicate(format: "wallet == nil")
    ) var uncategorisedReceipts: FetchedResults<Receipt>
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showAddWallet: Bool = false
    @State private var newWalletName: String = ""
    
    // warning prompts when deleting wallet
    @State private var walletToDelete: Wallet?
    @State private var showDeletePrompt: Bool = false
    
    private var filteredWallets: [Wallet] {
        wallets.filter {
            if $0.name == "Uncategorised Receipts" {
                return !$0.receiptsArray.isEmpty
            } else {
                return true
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredWallets) { wallet in
                    NavigationLink(destination: ReceiptListView(wallet: wallet)) {
                        Text(wallet.name ?? "Uncategorised Receipts")
                            .font(.headline)
                    }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        walletToDelete = filteredWallets[index]
                        showDeletePrompt = true
                    }
                }
            }
            .navigationTitle("Wallets")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showAddWallet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddWallet) {
                NavigationView {
                    Form {
                        TextField("Wallet Name", text: $newWalletName)
                    }
                    .navigationTitle(Text("Add Wallet"))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                addWallet()
                                showAddWallet = false
                            }
                            .disabled(newWalletName.isEmpty)
                        }
                            
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddWallet = false }
                        }
                    }
                }
            }
            .alert("Delete Wallet?", isPresented: $showDeletePrompt, presenting: walletToDelete) {
                wallet in
                Button("Delete", role: .destructive) {
                    if let index = filteredWallets.firstIndex(of: wallet) {
                        deleteWallet(at: IndexSet(integer: index))
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                wallet in
                Text("This will delete \(wallet.name ?? "wallet") and all its receipts")
            }
        }
    }
    
    func addWallet() {
        withAnimation {
            let newWallet = Wallet(context: viewContext)
            newWallet.name = newWalletName
            newWallet.createdAt = Date()
            do {
                try viewContext.save()
            } catch {
                // error handling
            }
            newWalletName = ""
        }
    }
    
    func deleteWallet(at offsets: IndexSet) {
        for idx in offsets { viewContext.delete(wallets[idx])}
        do {
            try viewContext.save()
        } catch {
            // error handling
        }
    }
    
//    func setOrphanReceiptsToUncategorised(context: NSManagedObjectContext) {
//        // create uncategorised expenses group
//        let walletFetch: NSFetchRequest<Wallet> = Wallet.fetchRequest()
//        
//        walletFetch.predicate = NSPredicate(format: "name == %@", "Uncategorised Receipts")
//        
//        walletFetch.fetchLimit = 1
//        
//        let wallet: Wallet
//        if let found = try? context.fetch(walletFetch), let existing = found.first {
//            wallet = existing
//        } else {
//            wallet = Wallet(context: context)
//            wallet.name = "Uncategorised Receipts"
//            wallet.createdAt = Date()
//        }
//        
//        // find expenses with no group and save in uncategorised
//        let receiptFetch: NSFetchRequest<Receipt> = Receipt.fetchRequest()
//        receiptFetch.predicate = NSPredicate(format: "wallet == nil")
//        
//        if let orphanReceipts = try? context.fetch(receiptFetch), !orphanReceipts.isEmpty {
//            for receipt in orphanReceipts {
//                receipt.wallet = wallet
//            }
//            try? context.save()
//        }
//    }
    
}
