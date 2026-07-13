//
//  Repositories.swift
//  SplitPals
//
//  Created by Chris Choong
//

import CoreData
import Foundation

/// Repository abstractions over the Core Data managers.
///
/// Views and services should depend on these protocols rather than the
/// concrete managers, so the storage backend (local today, CloudKit-synced
/// later) can change without touching call sites.

@MainActor
protocol PersonRepository {
    func createPerson(name: String, icon: String, isCurrentUser: Bool) throws -> Person
    func updatePerson(_ person: Person, name: String, icon: String) throws
    func deletePerson(_ person: Person) throws
    func fetchAllPersons() throws -> [Person]
    func fetchCurrentUser() throws -> Person?
}

@MainActor
protocol GroupRepository {
    func createGroup(name: String, gradientName: String, icon: String) throws -> ExpenseGroup
    func updateGroup(_ group: ExpenseGroup, name: String, gradientName: String, icon: String) throws
    func updateMembers(_ group: ExpenseGroup, members: [Person]) throws
    func deleteGroup(_ group: ExpenseGroup) throws
    func fetchAllGroups() throws -> [ExpenseGroup]
}

@MainActor
protocol ExpenseRepository {
    func createExpense(
        name: String,
        amount: Double,
        currency: Currency,
        group: ExpenseGroup,
        paidBy: Person?,
        splitType: SplitType,
        participants: [Person],
        exactAmounts: [Person: Double]?
    ) throws -> Expense

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
    ) throws

    func deleteExpense(_ expense: Expense) throws
    func fetchExpenses(for group: ExpenseGroup?) throws -> [Expense]
}

extension PersonManager: PersonRepository {}
extension GroupManager: GroupRepository {}
extension ExpenseManager: ExpenseRepository {}
