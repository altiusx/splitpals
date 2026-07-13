//
//  SettleUpView.swift
//  SplitPals
//
//  Created by Chris Choong
//

import SwiftUI
import CoreData

struct SettleUpView: View {
    /// How outstanding debts are presented for settling.
    enum SettleMode: String, CaseIterable, Identifiable {
        case manual
        case simplified

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .manual: return "Manual"
            case .simplified: return "Simplified"
            }
        }
    }

    /// A debt selected for recording, with the amount still editable.
    struct PendingPayment: Identifiable {
        let id = UUID()
        let debtor: Person
        let creditor: Person
        let outstanding: Double
    }

    @ObservedObject var group: ExpenseGroup

    @FetchRequest private var splits: FetchedResults<ExpenseSplit>
    @FetchRequest private var settlements: FetchedResults<Settlement>
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var errorHandler = ErrorHandler()

    /// Default settle-up currency behavior, configured in Settings.
    @AppStorage("settleUpUsesHomeCurrency") private var settleUpUsesHomeCurrency = false

    @State private var mode: SettleMode = .manual
    @State private var selectedCurrency: String?
    @State private var pendingPayment: PendingPayment?
    @State private var transferToConfirm: DebtSimplifier.Transfer<Person>?

    private var settlementManager: SettlementManager {
        SettlementManager(context: viewContext)
    }

    init(group: ExpenseGroup) {
        self.group = group
        _splits = FetchRequest(
            entity: ExpenseSplit.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \ExpenseSplit.id, ascending: true)],
            predicate: NSPredicate(format: "expense.group == %@", group)
        )
        _settlements = FetchRequest(
            entity: Settlement.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Settlement.createdAt, ascending: false)],
            predicate: NSPredicate(format: "group == %@", group)
        )
    }

    private var gradientColors: [Color] {
        AppCardGradient.colors(named: group.gradientName)
    }

    // MARK: - Display currency

    /// Currency codes used by the group's expenses, most used first.
    private var groupCurrencyCodes: [String] {
        var counts: [String: Int] = [:]
        for expense in group.expensesArray {
            if let code = expense.currency?.code {
                counts[code, default: 0] += 1
            }
        }
        return counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)
    }

    /// Group currencies plus the home currency, deduplicated.
    private var currencyOptions: [String] {
        var options = groupCurrencyCodes
        if !options.contains(exchangeRateService.baseCurrency) {
            options.append(exchangeRateService.baseCurrency)
        }
        return options
    }

    /// The currency balances are shown in: the user's pick, or the default
    /// from Settings (home currency, or the group's most used currency).
    private var displayCurrency: String {
        selectedCurrency ?? (
            settleUpUsesHomeCurrency
                ? exchangeRateService.baseCurrency
                : groupCurrencyCodes.first ?? exchangeRateService.baseCurrency
        )
    }

    private func convertToDisplay(amount: Double, from code: String) -> Double? {
        exchangeRateService.convert(amount: amount, from: code, to: displayCurrency)
    }

    // MARK: - Balances

    private var balances: [(person: Person, balance: Double)] {
        SettlementManager.netBalances(
            members: group.membersArray,
            splits: Array(splits),
            settlements: Array(settlements),
            displayCurrency: displayCurrency,
            convert: convertToDisplay
        )
    }

    private var pairwiseDebts: [DebtSimplifier.Transfer<Person>] {
        SettlementManager.pairwiseDebts(
            splits: Array(splits),
            settlements: Array(settlements),
            displayCurrency: displayCurrency,
            convert: convertToDisplay
        )
    }

    private var suggestedTransfers: [DebtSimplifier.Transfer<Person>] {
        SettlementManager.suggestedTransfers(
            members: group.membersArray,
            splits: Array(splits),
            settlements: Array(settlements),
            displayCurrency: displayCurrency,
            convert: convertToDisplay
        )
    }

    var body: some View {
        List {
            headerSection

            modeSection

            balancesSection

            paymentsSection

            historySection
        }
        .navigationTitle("Settle Up")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                currencyMenu
            }
        }
        .sheet(item: $pendingPayment) { payment in
            RecordPaymentSheet(
                payment: payment,
                currencyCode: displayCurrency,
                onRecord: { amount in
                    record(amount: amount, from: payment.debtor, to: payment.creditor)
                }
            )
        }
        .alert("Mark as Paid?", isPresented: Binding(
            get: { transferToConfirm != nil },
            set: { if !$0 { transferToConfirm = nil } }
        ), presenting: transferToConfirm) { transfer in
            Button("Mark as Paid") {
                record(amount: transfer.amount, from: transfer.debtor, to: transfer.creditor)
            }
            Button("Cancel", role: .cancel) {}
        } message: { transfer in
            Text("\(transfer.debtor.name ?? "Someone") pays \(transfer.creditor.name ?? "someone") \(formatDisplay(transfer.amount)). This records the payment in full.")
        }
        .errorAlert(errorHandler: errorHandler)
    }

    /// Picks the currency balances are displayed (and payments recorded) in.
    private var currencyMenu: some View {
        Menu {
            Picker("Currency", selection: Binding(
                get: { displayCurrency },
                set: { selectedCurrency = $0 }
            )) {
                ForEach(currencyOptions, id: \.self) { code in
                    if code == exchangeRateService.baseCurrency {
                        Text("\(code) (Home)").tag(code)
                    } else {
                        Text(code).tag(code)
                    }
                }
            }
        } label: {
            Text(displayCurrency)
                .font(.subheadline)
                .bold()
        }
        .accessibilityLabel("Display currency")
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

                Text("Balances in \(displayCurrency)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
        }
    }

    private var modeSection: some View {
        Section {
            Picker("Settle mode", selection: $mode) {
                ForEach(SettleMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } footer: {
            Text(mode == .manual
                 ? "Record payments person to person — partial amounts are fine."
                 : "Suggested payments settle everyone in the fewest transactions.")
        }
    }

    private var balancesSection: some View {
        Section("Balances") {
            ForEach(balances, id: \.person) { entry in
                HStack(spacing: 12) {
                    memberAvatar(entry.person)

                    Text(entry.person.displayName)
                        .font(.body)

                    Spacer()

                    balanceLabel(entry.balance)
                }
            }
        }
    }

    @ViewBuilder
    private var paymentsSection: some View {
        let debts = mode == .manual ? pairwiseDebts : suggestedTransfers

        Section {
            if debts.isEmpty {
                ContentUnavailableView(
                    "All Settled Up!",
                    systemImage: "checkmark.seal.fill",
                    description: Text("Nobody owes anything in this group.")
                )
            } else {
                ForEach(Array(debts.enumerated()), id: \.offset) { _, debt in
                    debtRow(debt)
                }
            }
        } header: {
            Text(mode == .manual ? "Who Owes Whom" : "Suggested Payments")
        } footer: {
            if !debts.isEmpty {
                Text(mode == .manual
                     ? "Amounts are approximate, converted to \(displayCurrency). Tap a debt to record a full or partial payment."
                     : "Amounts are approximate, converted to \(displayCurrency). Tap the checkmark once a payment has been made.")
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if !settlements.isEmpty {
            Section {
                ForEach(settlements) { settlement in
                    settlementRow(settlement)
                }
                .onDelete(perform: deleteSettlements)
            } header: {
                Text("Payments Made")
            } footer: {
                Text("Swipe to delete a payment recorded by mistake.")
            }
        }
    }

    // MARK: - Rows

    private func debtRow(_ debt: DebtSimplifier.Transfer<Person>) -> some View {
        HStack(spacing: 12) {
            memberAvatar(debt.debtor)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(debt.debtor.displayName) pays \(debt.creditor.displayName)")
                    .font(.body)
                Text(formatDisplay(debt.amount))
                    .font(.headline)
            }

            Spacer()

            if mode == .manual {
                Button {
                    pendingPayment = PendingPayment(
                        debtor: debt.debtor,
                        creditor: debt.creditor,
                        outstanding: debt.amount
                    )
                } label: {
                    Image(systemName: "square.and.pencil.circle")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Record a payment")
            } else {
                Button {
                    transferToConfirm = debt
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Mark payment as done")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if mode == .manual {
                pendingPayment = PendingPayment(
                    debtor: debt.debtor,
                    creditor: debt.creditor,
                    outstanding: debt.amount
                )
            }
        }
    }

    private func settlementRow(_ settlement: Settlement) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(settlement.payer?.displayName ?? "Someone") paid \(settlement.payee?.displayName ?? "someone")")
                .font(.body)
            HStack(spacing: 6) {
                Text(CurrencyFormatter.format(
                    amount: settlement.amount,
                    currencyCode: settlement.currencyCode ?? displayCurrency
                ))
                .font(.headline)

                if let date = settlement.createdAt {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func memberAvatar(_ person: Person) -> some View {
        Image(systemName: person.icon ?? "person.crop.circle")
            .font(.title2)
            .foregroundStyle(LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 36, height: 36)
    }

    @ViewBuilder
    private func balanceLabel(_ balance: Double) -> some View {
        let fractionDigits = CurrencyFormatter.fractionDigits(for: displayCurrency)
        let units = SplitCalculator.minorUnits(from: balance, fractionDigits: fractionDigits)

        if units == 0 {
            Text("Settled")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            Text(formatDisplay(balance, signed: true))
                .font(.headline)
                .foregroundStyle(units > 0 ? .green : .red)
        }
    }

    // MARK: - Helpers

    private func formatDisplay(_ amount: Double, signed: Bool = false) -> String {
        let formatted = CurrencyFormatter.format(amount: abs(amount), currencyCode: displayCurrency)
        if signed {
            return amount > 0 ? "+\(formatted)" : "−\(formatted)"
        }
        return formatted
    }

    private func record(amount: Double, from debtor: Person, to creditor: Person) {
        do {
            try settlementManager.recordSettlement(
                from: debtor,
                to: creditor,
                amount: amount,
                currencyCode: displayCurrency,
                in: group
            )
        } catch {
            errorHandler.handleCoreDataError(error, operation: .save)
        }
    }

    private func deleteSettlements(at offsets: IndexSet) {
        for index in offsets {
            do {
                try settlementManager.deleteSettlement(settlements[index])
            } catch {
                errorHandler.handleCoreDataError(error, operation: .delete)
            }
        }
    }
}

// MARK: - Record Payment Sheet

/// Form for recording a manual payment: the amount is prefilled with the
/// outstanding debt but can be lowered for a partial payment.
struct RecordPaymentSheet: View {
    let payment: SettleUpView.PendingPayment
    let currencyCode: String
    let onRecord: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @FocusState private var isAmountFocused: Bool

    private var fractionDigits: Int {
        CurrencyFormatter.fractionDigits(for: currencyCode)
    }

    private var enteredAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var enteredUnits: Int? {
        enteredAmount.map { SplitCalculator.minorUnits(from: $0, fractionDigits: fractionDigits) }
    }

    private var outstandingUnits: Int {
        SplitCalculator.minorUnits(from: payment.outstanding, fractionDigits: fractionDigits)
    }

    private var isValid: Bool {
        guard let units = enteredUnits else { return false }
        return units > 0 && units <= outstandingUnits
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("From", value: payment.debtor.displayName)
                    LabeledContent("To", value: payment.creditor.displayName)
                    LabeledContent("Outstanding", value: CurrencyFormatter.format(
                        amount: payment.outstanding,
                        currencyCode: currencyCode
                    ))
                }

                Section {
                    HStack {
                        Text(currencyCode)
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($isAmountFocused)
                    }
                } header: {
                    Text("Amount Paid")
                } footer: {
                    if let units = enteredUnits, units > outstandingUnits {
                        Text("Can't record more than the outstanding amount.")
                            .foregroundStyle(.red)
                    } else {
                        Text("Lower the amount for a partial payment.")
                    }
                }
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") {
                        if let amount = enteredAmount {
                            onRecord(amount)
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                amountText = String(format: "%.\(fractionDigits)f", payment.outstanding)
            }
            .task {
                // Focusing immediately makes the keyboard animate alongside
                // the sheet presentation, which stutters on device — let the
                // sheet settle first.
                try? await Task.sleep(for: .milliseconds(600))
                isAmountFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}
