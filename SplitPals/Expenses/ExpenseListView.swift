//
//  ExpenseListView.swift
//  SplitPals
//
//  Created by Chris Choong on 16/6/25.
//
import SwiftUI

struct ExpenseListView: View {
    @ObservedObject var group: ExpenseGroup

    @FetchRequest private var expenses: FetchedResults<Expense>
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var errorHandler = ErrorHandler()

    private var expenseManager: ExpenseManager {
        ExpenseManager(context: viewContext)
    }

    @State private var activeSheet: ExpenseSheet? = nil

    init(group: ExpenseGroup) {
        self.group = group
        _expenses = FetchRequest(
            entity: Expense.entity(),
            sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)],
            predicate: NSPredicate(format: "group == %@", group)
        )
    }

    private var convertedTotal: Double {
        var total = 0.0
        for expense in expenses {
            let code = expense.currency?.code ?? exchangeRateService.baseCurrency
            if code == exchangeRateService.baseCurrency {
                total += expense.amount
            } else if let converted = exchangeRateService.convert(amount: expense.amount, from: code) {
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
        let members = group.membersArray
        return max(members.count, 1)
    }

    private var currencyGroups: [(currency: Currency?, expenses: [Expense])] {
        let grouped = Dictionary(grouping: expenses, by: { $0.currency })
        let sortedKeys = grouped.keys.sorted { ($0?.name ?? "") < ($1?.name ?? "") }
        return sortedKeys.map { key in
            (currency: key, expenses: grouped[key] ?? [])
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

            ForEach(currencyGroups, id: \.currency) { currencyGroup in
                CurrencyExpensesSection(
                    currency: currencyGroup.currency,
                    expenses: currencyGroup.expenses,
                    onEdit: { expense in
                        activeSheet = .edit(expense.objectID)
                    },
                    onDelete: { indexSet in
                        deleteExpense(from: currencyGroup.expenses, at: indexSet)
                    })
            }
        }
        .navigationTitle(group.name ?? "Expenses")
        .toolbar {
            NavigationLink(destination: SettleUpView(group: group)) {
                Image(systemName: "arrow.left.arrow.right")
            }
            .accessibilityLabel("Settle Up")

            Button(action: {
                activeSheet = .add
            }) {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add Expense")
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add:
                AddEditExpense(group: group)
            case .edit(let objectID):
                if let expense = try? viewContext.existingObject(with: objectID) as? Expense {
                    AddEditExpense(expenseToEdit: expense, group: group)
                } else {
                    Text("This expense no longer exists.")
                }
            }
        }
        .errorAlert(errorHandler: errorHandler)
    }

    func deleteExpense(from expenses: [Expense], at offsets: IndexSet) {
        for index in offsets {
            let expense = expenses[index]
            do {
                try expenseManager.deleteExpense(expense)
            } catch {
                errorHandler.handleCoreDataError(error, operation: "delete")
            }
        }
    }
}
