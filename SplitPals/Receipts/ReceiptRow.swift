//
//  ReceiptRow.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//

import SwiftUI

struct ReceiptRow: View {
    @ObservedObject var receipt: Receipt
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    var body: some View {
        HStack {
            Text(receipt.name ?? "")
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount())
                if let converted = convertedAmount() {
                    Text(converted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func formattedAmount() -> String {
        guard let currency = receipt.currency else {
            return String(format: "%.2f", receipt.amount)
        }
        return CurrencyFormatter.format(amount: receipt.amount, currency: currency)
    }

    private func convertedAmount() -> String? {
        guard let code = receipt.currency?.code else { return nil }
        return exchangeRateService.formatConverted(amount: receipt.amount, from: code)
    }
}



