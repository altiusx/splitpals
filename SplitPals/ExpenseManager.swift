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
        group: ExpenseGroup
    ) throws -> Expense {
        let expense = Expense(context: context)
        expense.name = name
        expense.amount = amount
        expense.currency = currency
        expense.group = group
        expense.timestamp = Date()

        try context.save()
        return expense
    }

    // MARK: - Update

    func updateExpense(
        _ expense: Expense,
        name: String,
        amount: Double,
        currency: Currency,
        group: ExpenseGroup
    ) throws {
        expense.name = name
        expense.amount = amount
        expense.currency = currency
        expense.group = group

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
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        if let group = group {
            request.predicate = NSPredicate(format: "group == %@", group)
        } else {
            request.predicate = NSPredicate(format: "group == nil")
        }

        return try context.fetch(request)
    }
}
