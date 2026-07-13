//
//  SettlementManager.swift
//  SplitPals
//
//  Created by Chris Choong
//

import CoreData
import Foundation

/// Bridges the pure `DebtSimplifier` math to Core Data: computes per-group
/// balances from unpaid splits and recorded settlements, and records payments.
@MainActor
class SettlementManager {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Balances

    /// Net balance per member in the display currency, computed from unpaid
    /// splits minus recorded settlements. Positive = is owed money,
    /// negative = owes money.
    ///
    /// - Parameter convert: converts an amount from a currency code into the
    ///   display currency; return nil when no rate is available (the split is
    ///   then skipped, matching how group totals handle missing rates).
    static func netBalances(
        members: [Person],
        splits: [ExpenseSplit],
        settlements: [Settlement],
        displayCurrency: String,
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

            let code = expense.currency?.code ?? displayCurrency
            let converted = code == displayCurrency ? split.amount : convert(split.amount, code)
            guard let amount = converted else { continue }

            balances[debtor, default: 0] -= amount
            balances[payer, default: 0] += amount
        }

        // A recorded payment moves the payer toward zero and reduces what
        // the payee is owed.
        for settlement in settlements {
            guard let payer = settlement.payer,
                  let payee = settlement.payee,
                  payer != payee else { continue }

            let code = settlement.currencyCode ?? displayCurrency
            let converted = code == displayCurrency ? settlement.amount : convert(settlement.amount, code)
            guard let amount = converted else { continue }

            balances[payer, default: 0] += amount
            balances[payee, default: 0] -= amount
        }

        return balances
            .map { (person: $0.key, balance: $0.value) }
            .sorted { ($0.person.name ?? "") < ($1.person.name ?? "") }
    }

    /// Suggested settlement transactions, minimized greedily.
    static func suggestedTransfers(
        members: [Person],
        splits: [ExpenseSplit],
        settlements: [Settlement],
        displayCurrency: String,
        convert: (Double, String) -> Double?
    ) -> [DebtSimplifier.Transfer<Person>] {
        let balances = netBalances(
            members: members,
            splits: splits,
            settlements: settlements,
            displayCurrency: displayCurrency,
            convert: convert
        )
        let fractionDigits = CurrencyFormatter.fractionDigits(for: displayCurrency)
        return DebtSimplifier.minimalTransfers(
            balances: balances.map { (id: $0.person, balance: $0.balance) },
            fractionDigits: fractionDigits
        )
    }

    /// Who owes whom directly, without debt simplification: each unpaid
    /// split creates a debt from the split's person to the expense's payer,
    /// and recorded settlements pay debts down (overpayment flips the
    /// direction). Used by manual settle-up.
    static func pairwiseDebts(
        splits: [ExpenseSplit],
        settlements: [Settlement],
        displayCurrency: String,
        convert: (Double, String) -> Double?
    ) -> [DebtSimplifier.Transfer<Person>] {
        struct OrderedPair: Hashable {
            let debtor: Person
            let creditor: Person
        }

        let fractionDigits = CurrencyFormatter.fractionDigits(for: displayCurrency)
        // Accumulate in minor units so float residue can't create phantom debts.
        var owedUnits: [OrderedPair: Int] = [:]

        for split in splits {
            guard !split.isPaid,
                  let debtor = split.person,
                  let expense = split.expense,
                  let payer = expense.paidBy,
                  debtor != payer else { continue }

            let code = expense.currency?.code ?? displayCurrency
            let converted = code == displayCurrency ? split.amount : convert(split.amount, code)
            guard let amount = converted else { continue }

            owedUnits[OrderedPair(debtor: debtor, creditor: payer), default: 0]
                += SplitCalculator.minorUnits(from: amount, fractionDigits: fractionDigits)
        }

        for settlement in settlements {
            guard let payer = settlement.payer,
                  let payee = settlement.payee,
                  payer != payee else { continue }

            let code = settlement.currencyCode ?? displayCurrency
            let converted = code == displayCurrency ? settlement.amount : convert(settlement.amount, code)
            guard let amount = converted else { continue }

            owedUnits[OrderedPair(debtor: payer, creditor: payee), default: 0]
                -= SplitCalculator.minorUnits(from: amount, fractionDigits: fractionDigits)
        }

        var debts: [DebtSimplifier.Transfer<Person>] = []
        var processed: Set<Set<Person>> = []

        for pair in owedUnits.keys {
            let people: Set<Person> = [pair.debtor, pair.creditor]
            guard processed.insert(people).inserted else { continue }

            let forward = owedUnits[pair, default: 0]
            let reverse = owedUnits[OrderedPair(debtor: pair.creditor, creditor: pair.debtor), default: 0]
            let net = forward - reverse
            guard net != 0 else { continue }

            debts.append(DebtSimplifier.Transfer(
                debtor: net > 0 ? pair.debtor : pair.creditor,
                creditor: net > 0 ? pair.creditor : pair.debtor,
                amount: SplitCalculator.amount(fromMinorUnits: abs(net), fractionDigits: fractionDigits)
            ))
        }

        return debts.sorted {
            (($0.debtor.name ?? ""), ($0.creditor.name ?? "")) < (($1.debtor.name ?? ""), ($1.creditor.name ?? ""))
        }
    }

    // MARK: - Recording payments

    /// Records a payment from `payer` to `payee`. The amount may be partial;
    /// balances simply carry the remainder.
    @discardableResult
    func recordSettlement(
        from payer: Person,
        to payee: Person,
        amount: Double,
        currencyCode: String,
        in group: ExpenseGroup
    ) throws -> Settlement {
        let settlement = Settlement(context: context)
        settlement.id = UUID()
        settlement.amount = amount
        settlement.currencyCode = currencyCode
        settlement.createdAt = Date()
        settlement.payer = payer
        settlement.payee = payee
        settlement.group = group

        group.lastUpdated = Date()
        try context.save()
        return settlement
    }

    /// Removes a recorded payment (undo), restoring the debt it had settled.
    func deleteSettlement(_ settlement: Settlement) throws {
        settlement.group?.lastUpdated = Date()
        context.delete(settlement)
        try context.save()
    }
}
