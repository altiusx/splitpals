//
//  DebtSimplifier.swift
//  SplitPals
//
//  Created by Chris Choong
//

import Foundation

/// Greedy debt simplification, kept free of Core Data so it is unit-testable.
///
/// Given each member's net balance (positive = is owed money, negative =
/// owes money), it repeatedly matches the largest debtor with the largest
/// creditor, producing a near-minimal number of settlement transactions.
struct DebtSimplifier {

    struct Transfer<ID: Hashable>: Equatable {
        let debtor: ID
        let creditor: ID
        let amount: Double
    }

    /// Computes the minimal-ish set of transfers that settles all balances.
    ///
    /// - Parameter balances: net balance per member, in a single currency.
    ///   Order matters only for tie-breaking, so pass a deterministically
    ///   sorted array (e.g. by member name) for stable results.
    /// - Parameter fractionDigits: minor-unit precision of the currency.
    static func minimalTransfers<ID: Hashable>(
        balances: [(id: ID, balance: Double)],
        fractionDigits: Int = 2
    ) -> [Transfer<ID>] {
        // Work in minor units so tiny float residue can't create phantom transfers.
        var creditors: [(id: ID, units: Int)] = []
        var debtors: [(id: ID, units: Int)] = []

        for entry in balances {
            let units = SplitCalculator.minorUnits(from: entry.balance, fractionDigits: fractionDigits)
            if units > 0 {
                creditors.append((entry.id, units))
            } else if units < 0 {
                debtors.append((entry.id, -units))
            }
        }

        creditors.sort { $0.units > $1.units }
        debtors.sort { $0.units > $1.units }

        var transfers: [Transfer<ID>] = []
        var creditorIndex = 0
        var debtorIndex = 0

        while creditorIndex < creditors.count && debtorIndex < debtors.count {
            let payment = min(creditors[creditorIndex].units, debtors[debtorIndex].units)

            transfers.append(Transfer(
                debtor: debtors[debtorIndex].id,
                creditor: creditors[creditorIndex].id,
                amount: SplitCalculator.amount(fromMinorUnits: payment, fractionDigits: fractionDigits)
            ))

            creditors[creditorIndex].units -= payment
            debtors[debtorIndex].units -= payment

            if creditors[creditorIndex].units == 0 { creditorIndex += 1 }
            if debtors[debtorIndex].units == 0 { debtorIndex += 1 }
        }

        return transfers
    }
}
