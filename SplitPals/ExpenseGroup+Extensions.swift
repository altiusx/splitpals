//
//  ExpenseGroup+Extensions.swift
//  SplitPals
//
//  Created by Chris Choong on 16/6/25.
//
import Foundation

extension ExpenseGroup {
    var expensesArray: [Expense] {
        let set = expenses as? Set<Expense> ?? []
        return set.sorted {
            ($0.timestamp ?? Date()) > ($1.timestamp ?? Date())
        }
    }
}

