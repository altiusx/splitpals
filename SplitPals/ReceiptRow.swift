//
//  ExpenseRow.swift
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
        guard let currency = receipt.currency, let code = currency.code else {
            // fallback if currency missing
            return String(format: "%.2f", receipt.amount)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        // If you want to force your own symbol (optional!):
        if let symbol = currency.symbol { formatter.currencySymbol = symbol }

        // Optionally set min/max fraction digits based on code
        // but for most currencies, NumberFormatter does this for you

        return formatter.string(from: NSNumber(value: receipt.amount))
            ?? "\(currency.symbol ?? "")\(receipt.amount)"
    }
}



