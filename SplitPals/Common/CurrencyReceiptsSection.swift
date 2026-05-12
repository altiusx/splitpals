//
//  CurrencyReceiptsSection.swift
//  SplitPals
//
//  Created by Chris Choong on 22/6/25.
//
import SwiftUI

struct CurrencyReceiptsSection: View {
    let currency: Currency?
    let receipts: [Receipt]
    let onEdit: (Receipt) -> Void
    let onDelete: (IndexSet) -> Void
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    private var subtotal: Double {
        receipts.reduce(0) { $0 + $1.amount }
    }

    private var convertedSubtotal: String? {
        guard let code = currency?.code else { return nil }
        return exchangeRateService.formatConverted(amount: subtotal, from: code)
    }

    var body: some View {
        Section {
            ForEach(receipts, id: \.objectID) { receipt in
                ReceiptRow(receipt: receipt)
                    .contentShape(Rectangle())
                    .onTapGesture { onEdit(receipt) }
            }
            .onDelete(perform: onDelete)
        } header: {
            Text(currency?.name?.uppercased() ?? "UNKNOWN")
        } footer: {
            HStack {
                Spacer()
                if let currency = currency {
                    Text("Total: \(CurrencyFormatter.format(amount: subtotal, currency: currency))")
                        .font(.footnote)
                        .fontWeight(.medium)
                }
                if let converted = convertedSubtotal {
                    Text("(\(converted))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}


