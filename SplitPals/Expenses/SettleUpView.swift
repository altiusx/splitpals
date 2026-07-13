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
        let currencyCode: String
    }

    /// A simplified transfer awaiting "mark as paid" confirmation.
    struct PendingTransfer {
        let transfer: DebtSimplifier.Transfer<Person>
        let currencyCode: String
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
    @State private var convertToHomeOverride: Bool?
    @State private var pendingPayment: PendingPayment?
    @State private var transferToConfirm: PendingTransfer?

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

    private var homeCurrency: String {
        exchangeRateService.baseCurrency
    }

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

    /// Every currency with activity in the group: expense currencies plus any
    /// codes payments were recorded in (e.g. while converting to home currency).
    private var activeCurrencyCodes: [String] {
        var codes = groupCurrencyCodes
        for settlement in settlements {
            if let code = settlement.currencyCode, !codes.contains(code) {
                codes.append(code)
            }
        }
        return codes.isEmpty ? [homeCurrency] : codes
    }

    /// Whether balances are converted into the home currency instead of shown
    /// per currency: the user's pick, or the default from Settings.
    private var convertsToHome: Bool {
        convertToHomeOverride ?? settleUpUsesHomeCurrency
    }

    /// Converting is pointless when the home currency is the only one in play.
    private var offersHomeConversion: Bool {
        activeCurrencyCodes != [homeCurrency]
    }

    private func convertToHomeCurrency(amount: Double, from code: String) -> Double? {
        exchangeRateService.convert(amount: amount, from: code, to: homeCurrency)
    }

    private func splits(in code: String) -> [ExpenseSplit] {
        splits.filter { ($0.expense?.currency?.code ?? homeCurrency) == code }
    }

    private func settlements(in code: String) -> [Settlement] {
        settlements.filter { ($0.currencyCode ?? homeCurrency) == code }
    }

    // MARK: - Balances

    /// Net balances converted into the home currency.
    private var homeBalances: [(person: Person, balance: Double)] {
        SettlementManager.netBalances(
            members: group.membersArray,
            splits: Array(splits),
            settlements: Array(settlements),
            displayCurrency: homeCurrency,
            convert: convertToHomeCurrency
        )
    }

    /// Per member, the nonzero balances in each of the group's currencies.
    private var perCurrencyBalances: [(person: Person, amounts: [(code: String, balance: Double)])] {
        var amounts: [Person: [(code: String, balance: Double)]] = [:]
        for code in activeCurrencyCodes {
            let entries = SettlementManager.netBalances(
                members: group.membersArray,
                splits: splits(in: code),
                settlements: settlements(in: code),
                displayCurrency: code,
                convert: { amount, _ in amount }
            )
            let fractionDigits = CurrencyFormatter.fractionDigits(for: code)
            for entry in entries where SplitCalculator.minorUnits(from: entry.balance, fractionDigits: fractionDigits) != 0 {
                amounts[entry.person, default: []].append((code: code, balance: entry.balance))
            }
        }
        return group.membersArray
            .map { (person: $0, amounts: amounts[$0] ?? []) }
            .sorted { ($0.person.name ?? "") < ($1.person.name ?? "") }
    }

    /// Outstanding debts grouped by the currency they're settled in. In home
    /// conversion mode everything collapses into a single home-currency group.
    private var debtsByCurrency: [(code: String, debts: [DebtSimplifier.Transfer<Person>])] {
        if convertsToHome {
            let debts = SettlementManager.pairwiseDebts(
                splits: Array(splits),
                settlements: Array(settlements),
                displayCurrency: homeCurrency,
                convert: convertToHomeCurrency
            )
            return debts.isEmpty ? [] : [(code: homeCurrency, debts: debts)]
        }
        return activeCurrencyCodes.compactMap { code in
            let debts = SettlementManager.pairwiseDebts(
                splits: splits(in: code),
                settlements: settlements(in: code),
                displayCurrency: code,
                convert: { amount, _ in amount }
            )
            return debts.isEmpty ? nil : (code: code, debts: debts)
        }
    }

    /// Suggested minimal transfers, grouped by currency like `debtsByCurrency`.
    private var suggestedByCurrency: [(code: String, debts: [DebtSimplifier.Transfer<Person>])] {
        if convertsToHome {
            let transfers = SettlementManager.suggestedTransfers(
                members: group.membersArray,
                splits: Array(splits),
                settlements: Array(settlements),
                displayCurrency: homeCurrency,
                convert: convertToHomeCurrency
            )
            return transfers.isEmpty ? [] : [(code: homeCurrency, debts: transfers)]
        }
        return activeCurrencyCodes.compactMap { code in
            let transfers = SettlementManager.suggestedTransfers(
                members: group.membersArray,
                splits: splits(in: code),
                settlements: settlements(in: code),
                displayCurrency: code,
                convert: { amount, _ in amount }
            )
            return transfers.isEmpty ? nil : (code: code, debts: transfers)
        }
    }

    var body: some View {
        List {
            headerSection

            balancesSection

            paymentsSection

            historySection
        }
        .navigationTitle("Settle Up")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 8, for: .scrollContent)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if offersHomeConversion {
                    currencyMenu
                }
            }
        }
        .sheet(item: $pendingPayment) { payment in
            RecordPaymentSheet(
                payment: payment,
                currencyCode: payment.currencyCode,
                onRecord: { amount in
                    record(amount: amount, from: payment.debtor, to: payment.creditor, currencyCode: payment.currencyCode)
                }
            )
        }
        .alert("Mark as Paid?", isPresented: Binding(
            get: { transferToConfirm != nil },
            set: { if !$0 { transferToConfirm = nil } }
        ), presenting: transferToConfirm) { pending in
            Button("Mark as Paid") {
                record(
                    amount: pending.transfer.amount,
                    from: pending.transfer.debtor,
                    to: pending.transfer.creditor,
                    currencyCode: pending.currencyCode
                )
            }
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            Text("\(pending.transfer.debtor.name ?? "Someone") pays \(pending.transfer.creditor.name ?? "someone") \(format(pending.transfer.amount, code: pending.currencyCode)). This records the payment in full.")
        }
        .errorAlert(errorHandler: errorHandler)
    }

    /// Switches between showing each currency separately and converting
    /// everything into the home currency.
    private var currencyMenu: some View {
        Menu {
            Picker("Currency display", selection: Binding(
                get: { convertsToHome },
                set: { convertToHomeOverride = $0 }
            )) {
                Text("Each Currency").tag(false)
                Text("\(homeCurrency) (Home)").tag(true)
            }
        } label: {
            Text(convertsToHome ? homeCurrency : "All")
                .font(.subheadline)
                .bold()
        }
        .accessibilityLabel("Display currency")
    }

    // MARK: - Sections

    private var currencySubtitle: String {
        if convertsToHome || activeCurrencyCodes.count == 1 {
            return "Balances in \(convertsToHome ? homeCurrency : activeCurrencyCodes[0])"
        }
        return "Balances in each currency"
    }

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

                Text(currencySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Settle mode", selection: $mode) {
                    ForEach(SettleMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
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
            if convertsToHome {
                ForEach(homeBalances, id: \.person) { entry in
                    HStack(spacing: 12) {
                        memberAvatar(entry.person)

                        Text(entry.person.displayName)
                            .font(.body)

                        Spacer()

                        balanceLabel(entry.balance, code: homeCurrency)
                    }
                }
            } else {
                ForEach(perCurrencyBalances, id: \.person) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        memberAvatar(entry.person)

                        Text(entry.person.displayName)
                            .font(.body)

                        Spacer()

                        if entry.amounts.isEmpty {
                            Text("Settled")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .trailing, spacing: 2) {
                                ForEach(entry.amounts, id: \.code) { amount in
                                    balanceLabel(amount.balance, code: amount.code)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var paymentsSection: some View {
        let debtGroups = mode == .manual ? debtsByCurrency : suggestedByCurrency

        Section {
            if debtGroups.isEmpty {
                ContentUnavailableView(
                    "All Settled Up!",
                    systemImage: "checkmark.seal.fill",
                    description: Text("Nobody owes anything in this group.")
                )
            } else {
                ForEach(debtGroups, id: \.code) { entry in
                    ForEach(Array(entry.debts.enumerated()), id: \.offset) { _, debt in
                        debtRow(debt, code: entry.code)
                    }
                }
            }
        } header: {
            Text(mode == .manual ? "Who Owes Whom" : "Suggested Payments")
        } footer: {
            if !debtGroups.isEmpty {
                if convertsToHome {
                    Text(mode == .manual
                         ? "Amounts are approximate, converted to \(homeCurrency). Tap a debt to record a full or partial payment."
                         : "Amounts are approximate, converted to \(homeCurrency). Tap the checkmark once a payment has been made.")
                } else if activeCurrencyCodes.count > 1 {
                    Text(mode == .manual
                         ? "Each debt is settled in its own currency. Tap a debt to record a full or partial payment."
                         : "Payments are suggested per currency. Tap the checkmark once a payment has been made.")
                } else {
                    Text(mode == .manual
                         ? "Tap a debt to record a full or partial payment."
                         : "Tap the checkmark once a payment has been made.")
                }
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

    private func debtRow(_ debt: DebtSimplifier.Transfer<Person>, code: String) -> some View {
        HStack(spacing: 12) {
            memberAvatar(debt.debtor)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(debt.debtor.displayName) pays \(debt.creditor.displayName)")
                    .font(.body)
                Text(format(debt.amount, code: code))
                    .font(.headline)
            }

            Spacer()

            if mode == .manual {
                Button {
                    pendingPayment = PendingPayment(
                        debtor: debt.debtor,
                        creditor: debt.creditor,
                        outstanding: debt.amount,
                        currencyCode: code
                    )
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Record a payment")
            } else {
                Button {
                    transferToConfirm = PendingTransfer(transfer: debt, currencyCode: code)
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
                    outstanding: debt.amount,
                    currencyCode: code
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
                    currencyCode: settlement.currencyCode ?? homeCurrency
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
    private func balanceLabel(_ balance: Double, code: String) -> some View {
        let fractionDigits = CurrencyFormatter.fractionDigits(for: code)
        let units = SplitCalculator.minorUnits(from: balance, fractionDigits: fractionDigits)

        if units == 0 {
            Text("Settled")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            Text(format(balance, code: code, signed: true))
                .font(.headline)
                .foregroundStyle(units > 0 ? .green : .red)
        }
    }

    // MARK: - Helpers

    private func format(_ amount: Double, code: String, signed: Bool = false) -> String {
        let formatted = CurrencyFormatter.format(amount: abs(amount), currencyCode: code)
        if signed {
            return amount > 0 ? "+\(formatted)" : "−\(formatted)"
        }
        return formatted
    }

    private func record(amount: Double, from debtor: Person, to creditor: Person, currencyCode: String) {
        do {
            try settlementManager.recordSettlement(
                from: debtor,
                to: creditor,
                amount: amount,
                currencyCode: currencyCode,
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
