//
//  ExpenseRow.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//

import SwiftUI

struct ExpenseRow: View {
    @ObservedObject var expense: Expense
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    var body: some View {
        HStack {
            Text(expense.name ?? "")
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
        guard let currency = expense.currency else {
            return String(format: "%.2f", expense.amount)
        }
        return CurrencyFormatter.format(amount: expense.amount, currency: currency)
    }

    private func convertedAmount() -> String? {
        guard let code = expense.currency?.code else { return nil }
        return exchangeRateService.formatConverted(amount: expense.amount, from: code)
    }
}
