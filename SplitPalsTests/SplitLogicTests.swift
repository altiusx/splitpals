//
//  SplitLogicTests.swift
//  SplitPalsTests
//
//  Created by Chris Choong
//

import Testing
@testable import SplitPals

struct SplitCalculatorTests {

    @Test func equalSplitDividesEvenly() {
        let shares = SplitCalculator.equalShares(amount: 30.0, count: 3, fractionDigits: 2)
        #expect(shares == [10.0, 10.0, 10.0])
    }

    @Test func equalSplitDistributesRemainder() {
        let shares = SplitCalculator.equalShares(amount: 10.0, count: 3, fractionDigits: 2)
        #expect(shares == [3.34, 3.33, 3.33])
        #expect(SplitCalculator.validateExact(shares: shares, total: 10.0, fractionDigits: 2))
    }

    @Test func equalSplitZeroDecimalCurrency() {
        // e.g. JPY has no minor units
        let shares = SplitCalculator.equalShares(amount: 100, count: 3, fractionDigits: 0)
        #expect(shares == [34, 33, 33])
        #expect(shares.reduce(0, +) == 100)
    }

    @Test func equalSplitEmptyParticipants() {
        #expect(SplitCalculator.equalShares(amount: 10.0, count: 0, fractionDigits: 2).isEmpty)
    }

    @Test func exactSplitValidation() {
        #expect(SplitCalculator.validateExact(shares: [5.0, 5.0], total: 10.0, fractionDigits: 2))
        #expect(!SplitCalculator.validateExact(shares: [5.0, 4.99], total: 10.0, fractionDigits: 2))
    }

    @Test func exactValidationSurvivesFloatDrift() {
        // 0.1 + 0.2 != 0.3 in binary floating point; minor units must absorb it
        #expect(SplitCalculator.validateExact(shares: [0.1, 0.2], total: 0.3, fractionDigits: 2))
    }

    @Test func remainingReportsShortfall() {
        let remaining = SplitCalculator.remaining(shares: [3.0], total: 10.0, fractionDigits: 2)
        #expect(remaining == 7.0)
    }
}

struct DebtSimplifierTests {

    @Test func twoPersonDebt() {
        let transfers = DebtSimplifier.minimalTransfers(
            balances: [(id: "alice", balance: 10.0), (id: "bob", balance: -10.0)]
        )
        #expect(transfers == [.init(debtor: "bob", creditor: "alice", amount: 10.0)])
    }

    @Test func settledGroupNeedsNoTransfers() {
        let transfers = DebtSimplifier.minimalTransfers(
            balances: [(id: "alice", balance: 0.0), (id: "bob", balance: 0.0)]
        )
        #expect(transfers.isEmpty)
    }

    @Test func hubPayerGetsOneTransferPerDebtor() {
        // One person paid for everything: minimal solution is n-1 transfers.
        let transfers = DebtSimplifier.minimalTransfers(
            balances: [
                (id: "alice", balance: 20.0),
                (id: "bob", balance: -10.0),
                (id: "carol", balance: -10.0)
            ]
        )
        #expect(transfers.count == 2)
        #expect(transfers.allSatisfy { $0.creditor == "alice" && $0.amount == 10.0 })
    }

    @Test func greedyCollapsesChains() {
        // alice +20, bob -4, carol -16 → 2 transfers, not 3
        let transfers = DebtSimplifier.minimalTransfers(
            balances: [
                (id: "alice", balance: 20.0),
                (id: "bob", balance: -4.0),
                (id: "carol", balance: -16.0)
            ]
        )
        #expect(transfers == [
            .init(debtor: "carol", creditor: "alice", amount: 16.0),
            .init(debtor: "bob", creditor: "alice", amount: 4.0)
        ])
    }

    @Test func transfersConserveEveryBalance() {
        let balances: [(id: String, balance: Double)] = [
            (id: "a", balance: 35.5),
            (id: "b", balance: -12.25),
            (id: "c", balance: -3.75),
            (id: "d", balance: -19.5)
        ]
        let transfers = DebtSimplifier.minimalTransfers(balances: balances)

        var net = Dictionary(uniqueKeysWithValues: balances.map { ($0.id, $0.balance) })
        for transfer in transfers {
            net[transfer.debtor]! += transfer.amount
            net[transfer.creditor]! -= transfer.amount
        }
        for (_, remainder) in net {
            #expect(abs(remainder) < 0.005)
        }
    }

    @Test func subCentResidueIsIgnored() {
        // Balances that round to zero cents must not create phantom transfers.
        let transfers = DebtSimplifier.minimalTransfers(
            balances: [(id: "alice", balance: 0.001), (id: "bob", balance: -0.001)]
        )
        #expect(transfers.isEmpty)
    }
}
