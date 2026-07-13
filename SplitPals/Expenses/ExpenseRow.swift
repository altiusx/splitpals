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
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name ?? "")
                if let subtitle = splitSubtitle() {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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

    private func splitSubtitle() -> String? {
        guard let payer = expense.paidBy else { return nil }
        let payerName = payer.name ?? "Unknown"
        let participants = expense.participantsArray

        if participants.count > 1 {
            return "Paid by \(payerName) · Split \(participants.count) ways"
        }
        // A single participant who isn't the payer: paid on their behalf.
        if let only = participants.first, only != payer {
            return "Paid by \(payerName) · For \(only.name ?? "Unknown")"
        }
        return "Paid by \(payerName)"
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
