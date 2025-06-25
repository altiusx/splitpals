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
    
    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    enum ActiveSheet: Identifiable {
        case addWallet
        case editWallet(Wallet)
        case addReceipt(Wallet)

        var id: String {
            switch self {
            case .addWallet: return "addWallet"
            case .editWallet(let wallet): return "editWallet_\(wallet.objectID.uriRepresentation().absoluteString)"
            case .addReceipt(let wallet): return "addReceipt_\(wallet.objectID.uriRepresentation().absoluteString)"
            }
        }
    }
    
    @State private var activeSheet: ActiveSheet?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 20) {
                    ForEach(filteredWallets) { wallet in
                        NavigationLink(destination: ReceiptListView(wallet: wallet)) {
                            AppCardView(
                                icon: wallet.icon ?? "creditcard",
                                gradientColors: colorForWallet(wallet),
                                title: wallet.name ?? "Uncategorised Receipts",
                                onEdit: {
                                    activeSheet = .editWallet(wallet)
                                },
                                onAddReceipt: {
                                    activeSheet = .addReceipt(wallet)
                                },
                                onDelete: { walletToDelete = wallet; showDeletePrompt = true }
                            )
                            .aspectRatio(1.4, contentMode: .fit)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Wallets")
            .toolbar {
//                ToolbarItem(placement: .topBarLeading) {
//                    EditButton()
//                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { activeSheet = .addWallet }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addWallet:
                    AddEditWallet {
                        activeSheet = nil
                    }
                    .environment(\.managedObjectContext, viewContext)
                case .editWallet(let wallet):
                    AddEditWallet(walletToEdit: wallet) {
                        activeSheet = nil
                    }
                    .environment(\.managedObjectContext, viewContext)
                case .addReceipt(let wallet):
                    AddEditReceipt(wallet: wallet)
                }
            }
            .alert("Delete Wallet?", isPresented: $showDeletePrompt, presenting: walletToDelete) { wallet in
                Button("Delete", role: .destructive) {
                    if let index = filteredWallets.firstIndex(of: wallet) {
                        deleteWallet(at: IndexSet(integer: index))
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { wallet in
                Text("This will delete \(wallet.name ?? "wallet") and all its receipts")
            }
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
    
    func colorForWallet(_ wallet: Wallet) -> [Color] {
        guard let name = wallet.gradientName else {
            return cardGradients.first?.colors ?? [Color.blue, Color.purple]
        }
        return cardGradients.first(where: { $0.name == name })?.colors ?? [Color.blue, Color.purple]
    }

}
