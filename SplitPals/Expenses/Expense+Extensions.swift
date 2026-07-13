//
//  Expense+Extensions.swift
//  SplitPals
//
//  Created by Chris Choong
//

import Foundation

extension Expense {
    var splitsArray: [ExpenseSplit] {
        let set = splits as? Set<ExpenseSplit> ?? []
        return set.sorted { ($0.person?.name ?? "") < ($1.person?.name ?? "") }
    }

    var splitTypeValue: SplitType {
        SplitType(rawValue: splitType ?? "") ?? .equal
    }

    /// Everyone who has a share in this expense.
    var participantsArray: [Person] {
        splitsArray.compactMap(\.person)
    }
}
