//
//  SettlementFlowTests.swift
//  SplitPalsTests
//
//  Created by Chris Choong
//

import CoreData
import Testing
@testable import SplitPals

/// End-to-end manager tests over an in-memory store, modelled on a real
/// two-person group: Chris (current user) and Raymond.
@MainActor
struct SettlementFlowTests {

    private func makeStack() throws -> (
        context: NSManagedObjectContext,
        chris: Person,
        raymond: Person,
        group: ExpenseGroup,
        sgd: Currency
    ) {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let personManager = PersonManager(context: context)
        let chris = try personManager.createPerson(name: "Chris", icon: "person", isCurrentUser: true)
        let raymond = try personManager.createPerson(name: "Raymond", icon: "person")

        let groupManager = GroupManager(context: context)
        let group = try groupManager.createGroup(name: "Trip", gradientName: "Ocean", icon: "car")
        try groupManager.updateMembers(group, members: [chris, raymond])

        let request: NSFetchRequest<Currency> = Currency.fetchRequest()
        request.predicate = NSPredicate(format: "code == %@", "SGD")
        let sgd = try #require(try context.fetch(request).first)

        return (context, chris, raymond, group, sgd)
    }

    private func balances(
        for group: ExpenseGroup,
        members: [Person]
    ) -> [(person: Person, balance: Double)] {
        let splits = group.expensesArray.flatMap(\.splitsArray)
        return SettlementManager.netBalances(
            members: members,
            splits: splits,
            baseCurrency: "SGD",
            convert: { amount, _ in amount }
        )
    }

    @Test func paidByAndSplitsAreStored() throws {
        let stack = try makeStack()
        let expenseManager = ExpenseManager(context: stack.context)

        let expense = try expenseManager.createExpense(
            name: "Taxi",
            amount: 50,
            currency: stack.sgd,
            group: stack.group,
            paidBy: stack.raymond,
            splitType: .equal,
            participants: [stack.chris, stack.raymond],
            exactAmounts: nil
        )

        #expect(expense.paidBy == stack.raymond)
        #expect(expense.splitsArray.count == 2)
        let raymondSplit = try #require(expense.splitsArray.first { $0.person == stack.raymond })
        let chrisSplit = try #require(expense.splitsArray.first { $0.person == stack.chris })
        #expect(raymondSplit.isPaid)          // payer's own share is settled
        #expect(!chrisSplit.isPaid)
        #expect(chrisSplit.amount == 25)
    }

    /// The reported scenario as intended: Raymond's own S$50, Chris's own
    /// S$100, and S$100 split equally. Raymond should owe exactly S$50.
    @Test func personalExpensesPlusSharedExpense() throws {
        let stack = try makeStack()
        let expenseManager = ExpenseManager(context: stack.context)

        _ = try expenseManager.createExpense(
            name: "Raymond's own", amount: 50, currency: stack.sgd, group: stack.group,
            paidBy: stack.raymond, splitType: .equal,
            participants: [stack.raymond], exactAmounts: nil
        )
        _ = try expenseManager.createExpense(
            name: "Chris's own", amount: 100, currency: stack.sgd, group: stack.group,
            paidBy: stack.chris, splitType: .equal,
            participants: [stack.chris], exactAmounts: nil
        )
        _ = try expenseManager.createExpense(
            name: "Shared", amount: 100, currency: stack.sgd, group: stack.group,
            paidBy: stack.chris, splitType: .equal,
            participants: [stack.chris, stack.raymond], exactAmounts: nil
        )

        let result = balances(for: stack.group, members: [stack.chris, stack.raymond])
        #expect(result.first { $0.person == stack.chris }?.balance == 50)
        #expect(result.first { $0.person == stack.raymond }?.balance == -50)

        let transfers = DebtSimplifier.minimalTransfers(
            balances: result.map { (id: $0.person, balance: $0.balance) }
        )
        #expect(transfers.count == 1)
        #expect(transfers.first?.debtor == stack.raymond)
        #expect(transfers.first?.creditor == stack.chris)
        #expect(transfers.first?.amount == 50)
    }

    /// All three expenses split equally between both people.
    @Test func allSharedExpenses() throws {
        let stack = try makeStack()
        let expenseManager = ExpenseManager(context: stack.context)

        for (name, amount, payer) in [("A", 50.0, stack.raymond), ("B", 100.0, stack.chris), ("C", 100.0, stack.chris)] {
            _ = try expenseManager.createExpense(
                name: name, amount: amount, currency: stack.sgd, group: stack.group,
                paidBy: payer, splitType: .equal,
                participants: [stack.chris, stack.raymond], exactAmounts: nil
            )
        }

        // Raymond owes 50 + 50, Chris owes 25 → net 75
        let result = balances(for: stack.group, members: [stack.chris, stack.raymond])
        #expect(result.first { $0.person == stack.chris }?.balance == 75)
        #expect(result.first { $0.person == stack.raymond }?.balance == -75)
    }

    /// Reproduces the reported wrong numbers: if the S$50 expense is stored
    /// with Chris as payer (the default) instead of Raymond, the balances
    /// come out as exactly +100/−100 — the reported symptom.
    @Test func misattributedPayerProducesReportedNumbers() throws {
        let stack = try makeStack()
        let expenseManager = ExpenseManager(context: stack.context)

        _ = try expenseManager.createExpense(
            name: "Raymond's own, wrong payer", amount: 50, currency: stack.sgd, group: stack.group,
            paidBy: stack.chris, splitType: .equal,
            participants: [stack.raymond], exactAmounts: nil
        )
        _ = try expenseManager.createExpense(
            name: "Chris's own", amount: 100, currency: stack.sgd, group: stack.group,
            paidBy: stack.chris, splitType: .equal,
            participants: [stack.chris], exactAmounts: nil
        )
        _ = try expenseManager.createExpense(
            name: "Shared", amount: 100, currency: stack.sgd, group: stack.group,
            paidBy: stack.chris, splitType: .equal,
            participants: [stack.chris, stack.raymond], exactAmounts: nil
        )

        let result = balances(for: stack.group, members: [stack.chris, stack.raymond])
        #expect(result.first { $0.person == stack.chris }?.balance == 100)
        #expect(result.first { $0.person == stack.raymond }?.balance == -100)
    }

    /// Editing an expense to fix the payer must correct the balances.
    @Test func fixingPayerOnEditCorrectsBalances() throws {
        let stack = try makeStack()
        let expenseManager = ExpenseManager(context: stack.context)

        let expense = try expenseManager.createExpense(
            name: "Taxi", amount: 50, currency: stack.sgd, group: stack.group,
            paidBy: stack.chris, splitType: .equal,
            participants: [stack.raymond], exactAmounts: nil
        )

        try expenseManager.updateExpense(
            expense,
            name: "Taxi", amount: 50, currency: stack.sgd, group: stack.group,
            paidBy: stack.raymond, splitType: .equal,
            participants: [stack.raymond], exactAmounts: nil
        )

        #expect(expense.paidBy == stack.raymond)
        let result = balances(for: stack.group, members: [stack.chris, stack.raymond])
        #expect(result.allSatisfy { $0.balance == 0 })
    }
}
