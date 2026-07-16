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
    @FetchRequest private var splits: FetchedResults<ExpenseSplit>
    @FetchRequest private var settlements: FetchedResults<Settlement>
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
            sortDescriptors: [NSSortDescriptor(keyPath: \Expense.timestamp, ascending: false)],
            predicate: NSPredicate(format: "group == %@", group)
        )
        _splits = FetchRequest(
            entity: ExpenseSplit.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \ExpenseSplit.id, ascending: true)],
            predicate: NSPredicate(format: "expense.group == %@", group)
        )
        _settlements = FetchRequest(
            entity: Settlement.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Settlement.createdAt, ascending: false)],
            predicate: NSPredicate(format: "group == %@", group)
        )
    }

    /// The current user's net position in this group, converted into the home
    /// currency: positive when they're owed money, negative when they owe.
    private var myNetBalance: Double {
        let balances = SettlementManager.netBalances(
            members: group.membersArray,
            splits: Array(splits),
            settlements: Array(settlements),
            displayCurrency: exchangeRateService.baseCurrency,
            convert: { amount, code in
                exchangeRateService.convert(amount: amount, from: code)
            }
        )
        return balances.first { $0.person.isCurrentUser }?.balance ?? 0
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
                netBalanceHeader
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

    /// Whether the net balance involved any conversion into the home
    /// currency, making it approximate.
    private var netBalanceIsConverted: Bool {
        let home = exchangeRateService.baseCurrency
        return expenses.contains { ($0.currency?.code ?? home) != home }
            || settlements.contains { ($0.currencyCode ?? home) != home }
    }

    /// Your position in the group at a glance, mirroring settle up's colors.
    @ViewBuilder
    private var netBalanceHeader: some View {
        let home = exchangeRateService.baseCurrency
        let fractionDigits = CurrencyFormatter.fractionDigits(for: home)
        let units = SplitCalculator.minorUnits(from: myNetBalance, fractionDigits: fractionDigits)
        let converted = netBalanceIsConverted
        let formatted = CurrencyFormatter.format(amount: abs(myNetBalance), currencyCode: home)

        VStack(spacing: 4) {
            if units == 0 {
                Text("All Settled Up")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.secondary)
            } else {
                Text(units > 0 ? "You're owed" : "You owe")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(converted ? "~\(formatted)" : formatted)
                    .font(.system(size: 44, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(units > 0 ? Color.green : .red)
                if converted {
                    Text("Approximate, in \(home)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    func deleteExpense(from expenses: [Expense], at offsets: IndexSet) {
        for index in offsets {
            let expense = expenses[index]
            do {
                try expenseManager.deleteExpense(expense)
            } catch {
                errorHandler.handleCoreDataError(error, operation: .delete)
            }
        }
    }
}
