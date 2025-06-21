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

    var body: some View {
        Section(header:
            Text(currency?.name?.uppercased() ?? "UNKNOWN")) {
            ForEach(receipts, id: \.objectID) { receipt in
                ReceiptRow(receipt: receipt)
                    .contentShape(Rectangle())
                    .onTapGesture { onEdit(receipt) }
            }
            .onDelete(perform: onDelete)
        }
    }
}


