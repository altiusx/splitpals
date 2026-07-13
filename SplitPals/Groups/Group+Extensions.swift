//
//  Group+Extensions.swift
//  SplitPals
//
//  Created by Chris Choong on 16/6/25.
//
import Foundation

extension ExpenseGroup {
    var expensesArray: [Expense] {
        let set = expenses as? Set<Expense> ?? []
        return set.sorted {
            ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast)
        }
    }

    var membersArray: [Person] {
        let set = members as? Set<Person> ?? []
        return set.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
}
