//
//  CurrencyExpensesSection.swift
//  SplitPals
//
//  Created by Chris Choong on 22/6/25.
//
import SwiftUI

struct CurrencyExpensesSection: View {
    let currency: Currency?
    let expenses: [Expense]
    let onEdit: (Expense) -> Void
    let onDelete: (IndexSet) -> Void
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    private var subtotal: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    private var convertedSubtotal: String? {
        guard let code = currency?.code else { return nil }
        return exchangeRateService.formatConverted(amount: subtotal, from: code)
    }

    var body: some View {
        Section {
            ForEach(expenses, id: \.objectID) { expense in
                ExpenseRow(expense: expense)
                    .contentShape(Rectangle())
                    .onTapGesture { onEdit(expense) }
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
