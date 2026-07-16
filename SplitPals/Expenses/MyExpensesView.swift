//
//  MyExpensesView.swift
//  SplitPals
//
//  Created by Chris Choong
//

import SwiftUI
import CoreData

/// The Expenses tab: every expense the current user has a stake in, split
/// into what they owe and what they're owed, with search across all groups.
///
/// Amounts stay in the currency each expense was paid in, with the home
/// currency shown as a secondary conversion; the toolbar menu switches the
/// whole screen to home currency instead. Amounts are the original shares
/// from each expense — payments made afterwards are tracked on each group's
/// settle up screen.
struct MyExpensesView: View {
    /// An expense the current user has a stake in. `amount` is the user's
    /// share in the expense's currency: positive when others owe the user,
    /// negative when the user owes the payer.
    private struct Entry: Identifiable {
        let expense: Expense
        let amount: Double

        var id: NSManagedObjectID { expense.objectID }
    }

    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var exchangeRateService: ExchangeRateService

    @FetchRequest(
        entity: Expense.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Expense.timestamp, ascending: false)]
    ) private var expenses: FetchedResults<Expense>

    @FetchRequest(
        entity: Person.entity(),
        sortDescriptors: [],
        predicate: NSPredicate(format: "isCurrentUser == YES")
    ) private var currentUserResults: FetchedResults<Person>

    @State private var searchText = ""
    @State private var convertsToHome = false
    @State private var activeSheet: ExpenseSheet?

    private var homeCurrency: String {
        exchangeRateService.baseCurrency
    }

    // MARK: - Entries

    private var entries: [Entry] {
        guard let user = currentUserResults.first else { return [] }
        return expenses.compactMap { entry(for: $0, user: user) }
    }

    private var searchedEntries: [Entry] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            let expense = entry.expense
            return (expense.name ?? "").localizedCaseInsensitiveContains(query)
                || (expense.group?.name ?? "").localizedCaseInsensitiveContains(query)
                || (expense.paidBy?.name ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    private var owedToMe: [Entry] { searchedEntries.filter { $0.amount > 0 } }
    private var iOwe: [Entry] { searchedEntries.filter { $0.amount < 0 } }

    /// Converting is pointless when the home currency is the only one in play.
    private var offersHomeConversion: Bool {
        entries.contains { ($0.expense.currency?.code ?? homeCurrency) != homeCurrency }
    }

    /// The user's stake in one expense, or nil when it doesn't affect them
    /// (not involved, or a personal expense with no one else sharing it).
    private func entry(for expense: Expense, user: Person) -> Entry? {
        guard let payer = expense.paidBy else { return nil }

        if payer == user {
            let owedByOthers = expense.splitsArray
                .filter { $0.person != user }
                .reduce(0) { $0 + $1.amount }
            return owedByOthers > 0 ? Entry(expense: expense, amount: owedByOthers) : nil
        }

        guard let share = expense.splitsArray.first(where: { $0.person == user }),
              share.amount > 0 else { return nil }
        return Entry(expense: expense, amount: -share.amount)
    }

    // MARK: - Totals

    /// Totals per currency for entries matching `direction`, in each
    /// expense's own currency.
    private func currencyTotals(where direction: (Double) -> Bool) -> [(code: String, amount: Double)] {
        var totals: [String: Double] = [:]
        for entry in entries where direction(entry.amount) {
            let code = entry.expense.currency?.code ?? homeCurrency
            totals[code, default: 0] += entry.amount
        }
        return totals
            .map { (code: $0.key, amount: $0.value) }
            .sorted { $0.code < $1.code }
    }

    /// Total of entries matching `direction` converted into the home
    /// currency, skipping entries with no available rate (hence approximate).
    private func homeTotal(where direction: (Double) -> Bool) -> Double {
        entries.reduce(0) { total, entry in
            guard direction(entry.amount) else { return total }
            let code = entry.expense.currency?.code ?? homeCurrency
            let converted = code == homeCurrency
                ? entry.amount
                : exchangeRateService.convert(amount: entry.amount, from: code)
            return total + (converted ?? 0)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Shared Expenses",
                        systemImage: "receipt",
                        description: Text("Expenses you owe or are owed will show up here.")
                    )
                } else if searchedEntries.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    if searchText.isEmpty {
                        summarySection
                    }

                    if !iOwe.isEmpty {
                        entriesSection("You Owe", entries: iOwe)
                    }

                    if !owedToMe.isEmpty {
                        entriesSection("Owed to You", entries: owedToMe)
                    }
                }
            }
            .navigationTitle("Expenses")
            .searchable(text: $searchText, prompt: "Expense, group, or payer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if offersHomeConversion {
                        HomeConversionMenu(convertsToHome: $convertsToHome, homeCurrency: homeCurrency)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                if case .edit(let objectID) = sheet,
                   let expense = try? viewContext.existingObject(with: objectID) as? Expense {
                    AddEditExpense(expenseToEdit: expense, group: expense.group)
                } else {
                    Text("This expense no longer exists.")
                }
            }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section {
            summaryRow("You owe", direction: { $0 < 0 }, color: .red)
            summaryRow("You're owed", direction: { $0 > 0 }, color: .green)
        } footer: {
            Text(convertsToHome
                 ? "Approximate totals in \(homeCurrency), before payments. \(exchangeRateService.ratesDisclaimer)"
                 : "Totals before payments. Settle up in a group to record payments.")
        }
    }

    private func summaryRow(_ title: String, direction: (Double) -> Bool, color: Color) -> some View {
        let totals = convertsToHome
            ? [(code: homeCurrency, amount: homeTotal(where: direction))].filter { $0.amount != 0 }
            : currencyTotals(where: direction)

        return LabeledContent(title) {
            if totals.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(totals, id: \.code) { total in
                        Text(format(total.amount, code: total.code))
                            .foregroundStyle(color)
                            .bold()
                    }
                }
            }
        }
    }

    private func entriesSection(_ title: String, entries: [Entry]) -> some View {
        Section(title) {
            ForEach(entries) { entry in
                entryRow(entry)
            }
        }
    }

    private func entryRow(_ entry: Entry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.expense.name ?? "Expense")
                Text(entryCaption(entry.expense))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(shareText(entry))
                    .font(.headline)
                    .foregroundStyle(entry.amount > 0 ? .green : .red)

                if !convertsToHome, let converted = convertedCaption(entry) {
                    Text(converted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            activeSheet = .edit(entry.expense.objectID)
        }
    }

    // MARK: - Formatting

    private func entryCaption(_ expense: Expense) -> String {
        var parts: [String] = []
        if let groupName = expense.group?.name {
            parts.append(groupName)
        }
        if let payer = expense.paidBy, !payer.isCurrentUser {
            parts.append("Paid by \(payer.name ?? "Unknown")")
        }
        if let date = expense.timestamp {
            parts.append(date.formatted(date: .abbreviated, time: .omitted))
        }
        return parts.joined(separator: " · ")
    }

    /// The entry's share for display: its own currency by default, or the
    /// home currency when converting (falling back when no rate is known).
    private func shareText(_ entry: Entry) -> String {
        let code = entry.expense.currency?.code ?? homeCurrency
        if convertsToHome, code != homeCurrency,
           let converted = exchangeRateService.convert(amount: entry.amount, from: code) {
            return format(converted, code: homeCurrency)
        }
        return format(entry.amount, code: code, approximate: false)
    }

    /// The home-currency equivalent shown beneath a native amount, mirroring
    /// how group expense lists annotate other currencies.
    private func convertedCaption(_ entry: Entry) -> String? {
        let code = entry.expense.currency?.code ?? homeCurrency
        guard let formatted = exchangeRateService.formatConverted(amount: abs(entry.amount), from: code) else {
            return nil
        }
        return "~\(formatted)"
    }

    private func format(_ amount: Double, code: String, approximate: Bool? = nil) -> String {
        let formatted = CurrencyFormatter.format(amount: abs(amount), currencyCode: code)
        let isApproximate = approximate ?? convertsToHome
        return isApproximate ? "~\(formatted)" : formatted
    }
}
