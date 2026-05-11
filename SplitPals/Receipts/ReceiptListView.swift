//
//  ReceiptListView.swift
//  SplitPals
//
//  Created by Chris Choong on 16/6/25.
//
import SwiftUI

struct ReceiptListView: View {
    var wallet: Wallet?
    
    @FetchRequest private var receipts: FetchedResults<Receipt>

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var errorHandler = ErrorHandler()
    
    private var receiptManager: ReceiptManager {
        ReceiptManager(context: viewContext)
    }

    @State private var activeSheet: ReceiptSheet? = nil
    
    init(wallet: Wallet?) {
        self.wallet = wallet
        let sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        if let wallet = wallet {
            _receipts = FetchRequest(
                entity: Receipt.entity(),
                sortDescriptors: sortDescriptors,
                predicate: NSPredicate(format: "wallet == %@", wallet)
            )
        } else {
            _receipts = FetchRequest(
                entity: Receipt.entity(),
                sortDescriptors: sortDescriptors,
                predicate: NSPredicate(format: "wallet == nil")
            )
        }
    }

    var body: some View {
        let groups: [(currency: Currency?, receipts: [Receipt])] = {
            let grouped = Dictionary(grouping: receipts, by: { $0.currency })
            let sortedKeys = grouped.keys.sorted { ($0?.name ?? "") < ($1?.name ?? "") }
            return sortedKeys.map { (currency: Currency?) -> (currency: Currency?, receipts: [Receipt]) in
                let receiptsForCurrency: [Receipt] = grouped[currency] ?? []
                return (currency: currency, receipts: receiptsForCurrency)
            }
        }()
        NavigationView {
            List {
                ForEach(groups, id: \.currency) { group in
                    CurrencyReceiptsSection(
                        currency: group.currency,
                        receipts: group.receipts,
                        onEdit: {
                            receipt in
                                activeSheet = .edit(receipt.objectID)
                        },
                        onDelete: {
                            indexSet in
                                deleteReceipt(from: group.receipts, at: indexSet)
                        })
                    }
                }
            }
            .navigationTitle(wallet?.name ?? "Receipts")
            .toolbar {
                Button(action: {
                    activeSheet = .add
                }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add:
                    AddEditReceipt(wallet: wallet)
                case .edit(let objectID):
                    if let receipt = try? viewContext.existingObject(with: objectID) as? Receipt {
                        AddEditReceipt(receiptToEdit: receipt, wallet: wallet)
                    } else {
                        Text("This receipt no longer exists.")
                    }
                }
            }
            .errorAlert(errorHandler: errorHandler)
        }
    
    
    func deleteReceipt(from receipts: [Receipt], at offsets: IndexSet) {
        for index in offsets {
            let receipt = receipts[index]
            do {
                try receiptManager.deleteReceipt(receipt)
            } catch {
                errorHandler.handleCoreDataError(error, operation: "delete")
            }
        }
    }
}
