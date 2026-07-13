//
//  SplitCalculator.swift
//  SplitPals
//
//  Created by Chris Choong
//

import Foundation

/// How an expense is divided among its participants.
enum SplitType: String, CaseIterable, Identifiable {
    case equal
    case exact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .equal: return "Equally"
        case .exact: return "Exact Amounts"
        }
    }
}

/// Pure split math, kept free of Core Data so it is unit-testable.
/// All calculations work in minor units (e.g. cents) to avoid floating
/// point drift; remainders are distributed one minor unit at a time.
struct SplitCalculator {

    static func minorUnits(from amount: Double, fractionDigits: Int) -> Int {
        let multiplier = pow(10.0, Double(fractionDigits))
        return Int((amount * multiplier).rounded())
    }

    static func amount(fromMinorUnits units: Int, fractionDigits: Int) -> Double {
        let divisor = pow(10.0, Double(fractionDigits))
        return Double(units) / divisor
    }

    /// Divides `amount` equally into `count` shares. When the amount doesn't
    /// divide evenly, the leftover minor units go to the first shares, so the
    /// shares always sum exactly to the total.
    static func equalShares(amount: Double, count: Int, fractionDigits: Int) -> [Double] {
        guard count > 0 else { return [] }

        let totalUnits = minorUnits(from: amount, fractionDigits: fractionDigits)
        let baseShare = totalUnits / count
        let remainder = totalUnits % count

        return (0..<count).map { index in
            let units = baseShare + (index < remainder ? 1 : 0)
            return self.amount(fromMinorUnits: units, fractionDigits: fractionDigits)
        }
    }

    /// Whether manually entered shares sum exactly to the expense total.
    static func validateExact(shares: [Double], total: Double, fractionDigits: Int) -> Bool {
        let shareUnits = shares.reduce(0) { $0 + minorUnits(from: $1, fractionDigits: fractionDigits) }
        return shareUnits == minorUnits(from: total, fractionDigits: fractionDigits)
    }

    /// Difference between the expense total and the entered shares,
    /// positive when there is still money left to assign.
    static func remaining(shares: [Double], total: Double, fractionDigits: Int) -> Double {
        let shareUnits = shares.reduce(0) { $0 + minorUnits(from: $1, fractionDigits: fractionDigits) }
        let totalUnits = minorUnits(from: total, fractionDigits: fractionDigits)
        return amount(fromMinorUnits: totalUnits - shareUnits, fractionDigits: fractionDigits)
    }
}
