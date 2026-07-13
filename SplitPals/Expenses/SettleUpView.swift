//
//  SettleUpView.swift
//  SplitPals
//
//  Created by Chris Choong
//

import SwiftUI
import CoreData

struct SettleUpView: View {
    @ObservedObject var group: ExpenseGroup

    @FetchRequest private var splits: FetchedResults<ExpenseSplit>
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var errorHandler = ErrorHandler()

    @State private var transferToConfirm: DebtSimplifier.Transfer<Person>?

    private var settlementManager: SettlementManager {
        SettlementManager(context: viewContext)
    }

    init(group: ExpenseGroup) {
        self.group = group
        _splits = FetchRequest(
            entity: ExpenseSplit.entity(),
            sortDescriptors: [NSSortDescriptor(key: "id", ascending: true)],
            predicate: NSPredicate(format: "expense.group == %@", group)
        )
    }

    private var gradientColors: [Color] {
        cardGradients.first(where: { $0.name == group.gradientName })?.colors ?? [Color.blue, Color.purple]
    }

    private var balances: [(person: Person, balance: Double)] {
        SettlementManager.netBalances(
            members: group.membersArray,
            splits: Array(splits),
            baseCurrency: exchangeRateService.baseCurrency,
            convert: { amount, code in
                exchangeRateService.convert(amount: amount, from: code)
            }
        )
    }

    private var transfers: [DebtSimplifier.Transfer<Person>] {
        SettlementManager.suggestedTransfers(
            members: group.membersArray,
            splits: Array(splits),
            baseCurrency: exchangeRateService.baseCurrency,
            convert: { amount, code in
                exchangeRateService.convert(amount: amount, from: code)
            }
        )
    }

    var body: some View {
        List {
            headerSection

            balancesSection

            paymentsSection
        }
        .navigationTitle("Settle Up")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Mark as Paid?", isPresented: Binding(
            get: { transferToConfirm != nil },
            set: { if !$0 { transferToConfirm = nil } }
        ), presenting: transferToConfirm) { transfer in
            Button("Mark as Paid") {
                settle(transfer)
            }
            Button("Cancel", role: .cancel) {}
        } message: { transfer in
            Text("\(transfer.debtor.name ?? "Someone") pays \(transfer.creditor.name ?? "someone") \(formatBase(transfer.amount)). This settles all outstanding debts between them in this group.")
        }
        .errorAlert(errorHandler: errorHandler)
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.title)
                        .foregroundStyle(.white)
                }

                Text(group.name ?? "Group")
                    .font(.title3)
                    .bold()

                Text("Balances in \(exchangeRateService.baseCurrency)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
        }
    }

    private var balancesSection: some View {
        Section("Balances") {
            ForEach(balances, id: \.person) { entry in
                HStack(spacing: 12) {
                    memberAvatar(entry.person)

                    Text(displayName(for: entry.person))
                        .font(.body)

                    Spacer()

                    balanceLabel(entry.balance)
                }
            }
        }
    }

    @ViewBuilder
    private var paymentsSection: some View {
        Section {
            if transfers.isEmpty {
                ContentUnavailableView(
                    "All Settled Up!",
                    systemImage: "checkmark.seal.fill",
                    description: Text("Nobody owes anything in this group.")
                )
            } else {
                ForEach(Array(transfers.enumerated()), id: \.offset) { _, transfer in
                    transferRow(transfer)
                }
            }
        } header: {
            Text("Suggested Payments")
        } footer: {
            if !transfers.isEmpty {
                Text("Amounts are approximate, converted to \(exchangeRateService.baseCurrency). Tap the checkmark once a payment has been made.")
            }
        }
    }

    // MARK: - Rows

    private func transferRow(_ transfer: DebtSimplifier.Transfer<Person>) -> some View {
        HStack(spacing: 12) {
            memberAvatar(transfer.debtor)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(displayName(for: transfer.debtor)) pays \(displayName(for: transfer.creditor))")
                    .font(.body)
                Text(formatBase(transfer.amount))
                    .font(.headline)
            }

            Spacer()

            Button {
                transferToConfirm = transfer
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Mark payment as done")
        }
        .padding(.vertical, 4)
    }

    private func memberAvatar(_ person: Person) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 36, height: 36)

            Image(systemName: person.icon ?? "person.crop.circle")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func balanceLabel(_ balance: Double) -> some View {
        let fractionDigits = CurrencyFormatter.fractionDigits(for: exchangeRateService.baseCurrency)
        let units = SplitCalculator.minorUnits(from: balance, fractionDigits: fractionDigits)

        if units == 0 {
            Text("Settled")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            Text(formatBase(balance, signed: true))
                .font(.headline)
                .foregroundStyle(units > 0 ? .green : .red)
        }
    }

    // MARK: - Helpers

    private func displayName(for person: Person) -> String {
        person.isCurrentUser ? "\(person.name ?? "Me") (Me)" : (person.name ?? "Unknown")
    }

    private func formatBase(_ amount: Double, signed: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = exchangeRateService.baseCurrency
        let formatted = formatter.string(from: NSNumber(value: abs(amount))) ?? ""
        if signed {
            return amount > 0 ? "+\(formatted)" : "−\(formatted)"
        }
        return formatted
    }

    private func settle(_ transfer: DebtSimplifier.Transfer<Person>) {
        do {
            try settlementManager.settleDebts(
                between: transfer.debtor,
                and: transfer.creditor,
                in: group
            )
        } catch {
            errorHandler.handleCoreDataError(error, operation: "save")
        }
    }
}
