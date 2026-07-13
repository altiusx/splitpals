//
//  ExpenseManager.swift
//  SplitPals
//
//  Created by Chris Choong
//

import CoreData
import Foundation

@MainActor
class ExpenseManager {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Create

    func createExpense(
        name: String,
        amount: Double,
        currency: Currency,
        group: ExpenseGroup,
        paidBy: Person?,
        splitType: SplitType,
        participants: [Person],
        exactAmounts: [Person: Double]?
    ) throws -> Expense {
        let expense = Expense(context: context)
        expense.id = UUID()
        expense.name = name
        expense.amount = amount
        expense.currency = currency
        expense.group = group
        expense.timestamp = Date()

        try applySplit(
            to: expense,
            amount: amount,
            currency: currency,
            paidBy: paidBy,
            splitType: splitType,
            participants: participants,
            exactAmounts: exactAmounts
        )

        try context.save()
        return expense
    }

    // MARK: - Update

    func updateExpense(
        _ expense: Expense,
        name: String,
        amount: Double,
        currency: Currency,
        group: ExpenseGroup,
        paidBy: Person?,
        splitType: SplitType,
        participants: [Person],
        exactAmounts: [Person: Double]?
    ) throws {
        expense.name = name
        expense.amount = amount
        expense.currency = currency
        expense.group = group

        try applySplit(
            to: expense,
            amount: amount,
            currency: currency,
            paidBy: paidBy,
            splitType: splitType,
            participants: participants,
            exactAmounts: exactAmounts
        )

        try context.save()
    }

    // MARK: - Delete

    func deleteExpense(_ expense: Expense) throws {
        context.delete(expense)
        try context.save()
    }

    // MARK: - Fetch

    func fetchExpenses(for group: ExpenseGroup?) throws -> [Expense] {
        let request = Expense.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.timestamp, ascending: false)]

        if let group = group {
            request.predicate = NSPredicate(format: "group == %@", group)
        } else {
            request.predicate = NSPredicate(format: "group == nil")
        }

        return try context.fetch(request)
    }

    // MARK: - Split

    /// Rebuilds the expense's splits for the given participants. Paid status
    /// is preserved for a participant whose share amount is unchanged.
    private func applySplit(
        to expense: Expense,
        amount: Double,
        currency: Currency,
        paidBy: Person?,
        splitType: SplitType,
        participants: [Person],
        exactAmounts: [Person: Double]?
    ) throws {
        let fractionDigits = CurrencyFormatter.fractionDigits(for: currency.code ?? "USD")

        let shares: [(person: Person, amount: Double)]
        switch splitType {
        case .equal:
            guard !participants.isEmpty else {
                throw AppError.invalidInput("Select at least one person to split between")
            }
            let amounts = SplitCalculator.equalShares(
                amount: amount,
                count: participants.count,
                fractionDigits: fractionDigits
            )
            shares = Array(zip(participants, amounts))
        case .exact:
            guard let exactAmounts, !exactAmounts.isEmpty else {
                throw AppError.invalidInput("Enter an amount for each person")
            }
            let entered = participants.compactMap { person in
                exactAmounts[person].map { (person: person, amount: $0) }
            }
            guard entered.count == participants.count else {
                throw AppError.invalidInput("Enter an amount for each person")
            }
            guard SplitCalculator.validateExact(
                shares: entered.map(\.amount),
                total: amount,
                fractionDigits: fractionDigits
            ) else {
                throw AppError.invalidInput("The split amounts must add up to the total expense")
            }
            shares = entered
        }

        expense.splitType = splitType.rawValue
        expense.paidBy = paidBy

        // Remember previous paid state before rebuilding.
        var previousPaidState: [Person: (amount: Double, paidAt: Date?)] = [:]
        for split in expense.splitsArray {
            if let person = split.person, split.isPaid {
                previousPaidState[person] = (split.amount, split.paidAt)
            }
            context.delete(split)
        }

        for share in shares {
            let split = ExpenseSplit(context: context)
            split.id = UUID()
            split.amount = share.amount
            split.person = share.person
            split.expense = expense

            if share.person == paidBy {
                // The payer's own share is settled by definition.
                split.isPaid = true
                split.paidAt = expense.timestamp
            } else if let previous = previousPaidState[share.person], previous.amount == share.amount {
                split.isPaid = true
                split.paidAt = previous.paidAt
            } else {
                split.isPaid = false
                split.paidAt = nil
            }
        }
    }
}
