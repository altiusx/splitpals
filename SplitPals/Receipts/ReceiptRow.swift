//
//  ReceiptRow.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//

import SwiftUI

struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack {
            Text(receipt.name ?? "")
            Spacer()
            Text(formattedAmount())
        }
    }

    private func formattedAmount() -> String {
        guard let currency = receipt.currency else {
            return String(format: "%.2f", receipt.amount)
        }
        return CurrencyFormatter.format(amount: receipt.amount, currency: currency)
    }
}



