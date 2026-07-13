//
//  SettlementManager.swift
//  SplitPals
//
//  Created by Chris Choong
//

import CoreData
import Foundation

/// Bridges the pure `DebtSimplifier` math to Core Data: computes per-group
/// balances from unpaid splits and records settlements.
@MainActor
class SettlementManager {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Balances

    /// Net balance per member in the base currency, computed from unpaid
    /// splits. Positive = is owed money, negative = owes money.
    ///
    /// - Parameter convert: converts an amount from a currency code into the
    ///   base currency; return nil when no rate is available (the split is
    ///   then skipped, matching how group totals handle missing rates).
    static func netBalances(
        members: [Person],
        splits: [ExpenseSplit],
        baseCurrency: String,
        convert: (Double, String) -> Double?
    ) -> [(person: Person, balance: Double)] {
        var balances: [Person: Double] = [:]
        for member in members {
            balances[member] = 0
        }

        for split in splits {
            guard !split.isPaid,
                  let debtor = split.person,
                  let expense = split.expense,
                  let payer = expense.paidBy,
                  debtor != payer else { continue }

            let code = expense.currency?.code ?? baseCurrency
            let converted = code == baseCurrency ? split.amount : convert(split.amount, code)
            guard let amount = converted else { continue }

            balances[debtor, default: 0] -= amount
            balances[payer, default: 0] += amount
        }

        return balances
            .map { (person: $0.key, balance: $0.value) }
            .sorted { ($0.person.name ?? "") < ($1.person.name ?? "") }
    }

    /// Suggested settlement transactions, minimized greedily.
    static func suggestedTransfers(
        members: [Person],
        splits: [ExpenseSplit],
        baseCurrency: String,
        convert: (Double, String) -> Double?
    ) -> [DebtSimplifier.Transfer<Person>] {
        let balances = netBalances(
            members: members,
            splits: splits,
            baseCurrency: baseCurrency,
            convert: convert
        )
        let fractionDigits = CurrencyFormatter.fractionDigits(for: baseCurrency)
        return DebtSimplifier.minimalTransfers(
            balances: balances.map { (id: $0.person, balance: $0.balance) },
            fractionDigits: fractionDigits
        )
    }

    // MARK: - Recording payments

    /// Marks every unpaid split between the two people (in both directions)
    /// within the group as paid.
    func settleDebts(between debtor: Person, and creditor: Person, in group: ExpenseGroup) throws {
        let now = Date()

        for expense in group.expensesArray {
            guard let payer = expense.paidBy else { continue }

            for split in expense.splitsArray where !split.isPaid {
                guard let person = split.person else { continue }
                let isDirectDebt = person == debtor && payer == creditor
                let isReverseDebt = person == creditor && payer == debtor
                if isDirectDebt || isReverseDebt {
                    split.isPaid = true
                    split.paidAt = now
                }
            }
        }

        group.lastUpdated = now
        try context.save()
    }
}
