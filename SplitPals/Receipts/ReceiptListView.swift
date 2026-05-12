//
//  ReceiptListView.swift
//  SplitPals
//
//  Created by Chris Choong on 16/6/25.
//
import SwiftUI

struct ReceiptListView: View {
    @ObservedObject var wallet: Wallet

    @FetchRequest private var receipts: FetchedResults<Receipt>
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var errorHandler = ErrorHandler()

    private var receiptManager: ReceiptManager {
        ReceiptManager(context: viewContext)
    }

    @State private var activeSheet: ReceiptSheet? = nil

    init(wallet: Wallet) {
        self.wallet = wallet
        _receipts = FetchRequest(
            entity: Receipt.entity(),
            sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)],
            predicate: NSPredicate(format: "wallet == %@", wallet)
        )
    }

    private var convertedTotal: Double {
        var total = 0.0
        for receipt in receipts {
            let code = receipt.currency?.code ?? exchangeRateService.baseCurrency
            if code == exchangeRateService.baseCurrency {
                total += receipt.amount
            } else if let converted = exchangeRateService.convert(amount: receipt.amount, from: code) {
                total += converted
            }
        }
        return total
    }

    private var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = exchangeRateService.baseCurrency
        return "~\(formatter.string(from: NSNumber(value: convertedTotal)) ?? "")"
    }

    private var participantCount: Int {
        let members = wallet.membersArray
        return max(members.count, 1)
    }

    private var groups: [(currency: Currency?, receipts: [Receipt])] {
        let grouped = Dictionary(grouping: receipts, by: { $0.currency })
        let sortedKeys = grouped.keys.sorted { ($0?.name ?? "") < ($1?.name ?? "") }
        return sortedKeys.map { key in
            (currency: key, receipts: grouped[key] ?? [])
        }
    }

    var body: some View {
        List {
                Section {
                    VStack(spacing: 4) {
                        Text(formattedTotal)
                            .font(.system(size: 48, weight: .bold))
                            .minimumScaleFactor(0.5)
                        Text("Total in \(exchangeRateService.baseCurrency)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Participants: \(participantCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }

                ForEach(groups, id: \.currency) { group in
                    CurrencyReceiptsSection(
                        currency: group.currency,
                        receipts: group.receipts,
                        onEdit: { receipt in
                            activeSheet = .edit(receipt.objectID)
                        },
                        onDelete: { indexSet in
                            deleteReceipt(from: group.receipts, at: indexSet)
                        })
                }
            }
            .navigationTitle(wallet.name ?? "Receipts")
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
