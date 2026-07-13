//
//  AddEditExpense.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//

import SwiftUI
import CoreData
import UIKit

struct AddEditExpense: View {

    var expenseToEdit: Expense? = nil
    var group: ExpenseGroup?
    var onSave: (() -> Void)? = nil

    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(entity: ExpenseGroup.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \ExpenseGroup.name, ascending: true)]
    ) var groups: FetchedResults<ExpenseGroup>

    @State private var selectedGroup: ExpenseGroup? = nil

    // currencies and value
    @FetchRequest(
        entity: Currency.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Currency.name, ascending: true)]
    ) var currencies: FetchedResults<Currency>

    @State private var name: String = ""
    @State private var rawAmount: String = ""
    @State private var selectedCurrency: Currency? = nil
    @FocusState private var isAmountFieldFocused: Bool
    @State private var shouldClearOnInput: Bool = false

    // Split
    @State private var paidBy: Person? = nil
    @State private var splitType: SplitType = .equal
    @State private var participants: Set<Person> = []
    @State private var exactAmountTexts: [Person: String] = [:]

    // Error Handling
    @StateObject private var errorHandler = ErrorHandler()

    // Managers
    private var expenseManager: ExpenseManager {
        ExpenseManager(context: viewContext)
    }

    private var members: [Person] {
        selectedGroup?.membersArray ?? []
    }

    var fractionDigits: Int {
        guard let currency = selectedCurrency, let code = currency.code else { return 2 }
        return CurrencyFormatter.fractionDigits(for: code)
    }

    var amount: Double {
        let divisor = pow(10.0, Double(fractionDigits))
        return (Double(Int(rawAmount) ?? 0)) / divisor
    }

    var formattedAmount: String {
        guard let currency = selectedCurrency else { return "$0.00" }
        return CurrencyFormatter.format(amount: amount, currency: currency)
    }

    private var sortedParticipants: [Person] {
        members.filter { participants.contains($0) }
    }

    private var exactAmounts: [Person: Double] {
        var amounts: [Person: Double] = [:]
        for person in sortedParticipants {
            if let text = exactAmountTexts[person],
               let value = Double(text.replacingOccurrences(of: ",", with: ".")) {
                amounts[person] = value
            }
        }
        return amounts
    }

    private var exactRemaining: Double {
        SplitCalculator.remaining(
            shares: sortedParticipants.compactMap { exactAmounts[$0] },
            total: amount,
            fractionDigits: fractionDigits
        )
    }

    private var isExactSplitValid: Bool {
        exactAmounts.count == sortedParticipants.count &&
        SplitCalculator.validateExact(
            shares: sortedParticipants.compactMap { exactAmounts[$0] },
            total: amount,
            fractionDigits: fractionDigits
        )
    }

    private var isSplitValid: Bool {
        guard !participants.isEmpty, paidBy != nil else { return false }
        return splitType == .equal || isExactSplitValid
    }

    var body: some View {
        NavigationView{
            Form{
                Section(header: Text("Details")){
                    TextField("Description", text: $name)

                    ZStack(alignment: .leading) {
                        // show the formatted amount as text
                        Text(formattedAmount)
                            .font(.title2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isAmountFieldFocused = true
                            }
                        // hidden textfield that receives user input
                        TextField("", text: $rawAmount)
                            .keyboardType(.numberPad)
                            .focused($isAmountFieldFocused)
                            .opacity(0)
                            .allowsHitTesting(false)
                            .onChange(of: rawAmount) {
                                if shouldClearOnInput {
                                    let newDigit = rawAmount.filter { $0.isNumber }.suffix(1)
                                    rawAmount = String(newDigit)
                                    shouldClearOnInput = false
                                    return
                                }
                                let filtered = rawAmount.filter {$0.isNumber}
                                if filtered != rawAmount {
                                    rawAmount = filtered
                                }
                            }
                    }
                }
                Section(header: Text("Currency")) {
                    Picker("Currency", selection: $selectedCurrency) {
                        if selectedCurrency == nil {
                            Text("Select a currency").tag(nil as Currency?)
                        }
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency.name ?? "").tag(currency as Currency?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section(header: Text("Group")) {
                    Picker("Group", selection: $selectedGroup) {
                        if selectedGroup == nil {
                            Text("Select a group").tag(nil as ExpenseGroup?)
                        }
                        ForEach(groups, id: \.self) { group in
                            Text(group.name ?? "Unnamed Group").tag(group as ExpenseGroup?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if !members.isEmpty {
                    splitSection
                }
            }
            .navigationTitle(expenseToEdit == nil ? "Add Expense" : "Edit Expense")
            .onAppear(perform: configureInitialState)
            .onChange(of: selectedGroup) { oldValue, _ in
                // Skip the initial prefill in edit mode so the expense's
                // saved participants aren't overwritten.
                if expenseToEdit != nil && oldValue == nil { return }
                resetSplitDefaults()
            }
            .toolbar{
                ToolbarItem(placement: .confirmationAction){
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(selectedCurrency == nil || Int(rawAmount) == nil || name.isEmpty || rawAmount.isEmpty || selectedGroup == nil || !isSplitValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .errorAlert(errorHandler: errorHandler)
        }
    }

    // MARK: - Split UI

    @ViewBuilder
    private var splitSection: some View {
        Section {
            Picker("Split", selection: $splitType) {
                ForEach(SplitType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            ForEach(members, id: \.self) { member in
                memberRow(member)
            }
        } header: {
            Text("Split Between")
        } footer: {
            splitFooter
        }
    }

    @ViewBuilder
    private func memberRow(_ member: Person) -> some View {
        let isSelected = participants.contains(member)
        let isPayer = paidBy == member

        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

            Image(systemName: member.icon ?? "person.crop.circle")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(for: member))
                if isPayer {
                    Text("Paid")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            if isSelected {
                if splitType == .exact {
                    TextField("0", text: exactAmountBinding(for: member))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                } else if !sortedParticipants.isEmpty {
                    Text(equalShareText(for: member))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                paidBy = member
            } label: {
                Image(systemName: isPayer ? "dollarsign.circle.fill" : "dollarsign.circle")
                    .font(.title3)
                    .foregroundStyle(isPayer ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isPayer ? "\(displayName(for: member)) paid" : "Mark \(displayName(for: member)) as the payer")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleParticipant(member)
        }
    }

    @ViewBuilder
    private var splitFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if participants.isEmpty {
                Text("Select at least one person to split between.")
            } else if splitType == .exact {
                if isExactSplitValid {
                    Text("All \(formattedAmount) assigned.")
                } else if let currency = selectedCurrency {
                    Text("\(CurrencyFormatter.format(amount: exactRemaining, currency: currency)) left to assign.")
                        .foregroundStyle(.red)
                }
            }

            if let payer = paidBy, !participants.isEmpty {
                Text("\(displayName(for: payer)) pays \(formattedAmount) for \(participantSummary).")
                    .fontWeight(.medium)
            }

            Text("Tap the checkmark to include someone in the split, and the dollar sign to change who paid.")
        }
    }

    private var participantSummary: String {
        let names = sortedParticipants.map { $0.isCurrentUser ? "Me" : ($0.name ?? "Unknown") }
        if names.count == members.count && names.count > 1 {
            return "everyone"
        }
        return names.joined(separator: ", ")
    }

    private func equalShareText(for member: Person) -> String {
        guard let currency = selectedCurrency else { return "" }
        let shares = SplitCalculator.equalShares(
            amount: amount,
            count: sortedParticipants.count,
            fractionDigits: fractionDigits
        )
        guard let index = sortedParticipants.firstIndex(of: member), index < shares.count else { return "" }
        return CurrencyFormatter.format(amount: shares[index], currency: currency)
    }

    private func exactAmountBinding(for member: Person) -> Binding<String> {
        Binding(
            get: { exactAmountTexts[member] ?? "" },
            set: { exactAmountTexts[member] = $0 }
        )
    }

    private func toggleParticipant(_ member: Person) {
        if participants.contains(member) {
            participants.remove(member)
        } else {
            participants.insert(member)
        }
    }

    private func displayName(for member: Person) -> String {
        if member.isCurrentUser {
            return "\(member.name ?? "Me") (Me)"
        }
        return member.name ?? "Unknown"
    }

    // MARK: - State setup

    private func configureInitialState() {
        if let expense = expenseToEdit {
            name = expense.name ?? ""

            // Use CurrencyFormatter to convert amount to raw string
            if let currency = expense.currency {
                rawAmount = CurrencyFormatter.convertToRawAmount(expense.amount, currency: currency)
            }

            selectedCurrency = expense.currency
            selectedGroup = expense.group
            shouldClearOnInput = true

            splitType = expense.splitTypeValue
            paidBy = expense.paidBy ?? defaultPayer()

            let existingParticipants = expense.participantsArray
            if existingParticipants.isEmpty {
                // Legacy expense without splits: default to everyone.
                participants = Set(members)
            } else {
                participants = Set(existingParticipants)
            }

            for split in expense.splitsArray {
                if let person = split.person, let currency = expense.currency, let code = currency.code {
                    let digits = CurrencyFormatter.fractionDigits(for: code)
                    exactAmountTexts[person] = String(format: "%.\(digits)f", split.amount)
                }
            }
        } else {
            // Set default group
            if selectedGroup == nil {
                if let currentGroup = group {
                    selectedGroup = currentGroup
                } else if !groups.isEmpty {
                    selectedGroup = groups.first
                }
            }

            // Set default currency based on user's locale
            if selectedCurrency == nil, !currencies.isEmpty {
                let defaultCode = CurrencyFormatter.defaultCurrencyCode()
                selectedCurrency = currencies.first(where: { $0.code == defaultCode }) ?? currencies.first
            }

            resetSplitDefaults()
        }
    }

    private func resetSplitDefaults() {
        participants = Set(members)
        exactAmountTexts = [:]
        if let payer = paidBy, members.contains(payer) {
            return
        }
        paidBy = defaultPayer()
    }

    private func defaultPayer() -> Person? {
        if let currentUser = try? AuthService.shared.currentUser(in: viewContext),
           members.contains(currentUser) {
            return currentUser
        }
        return members.first
    }

    // MARK: - Save

    private func saveExpense() {
        guard let currency = selectedCurrency else {
            errorHandler.handle(.missingCurrency)
            return
        }

        guard let group = selectedGroup else {
            errorHandler.handle(.missingGroup)
            return
        }

        guard !name.isEmpty else {
            errorHandler.handle(.invalidInput("Please enter a description"))
            return
        }

        guard !rawAmount.isEmpty, Int(rawAmount) != nil else {
            errorHandler.handle(.invalidInput("Please enter an amount"))
            return
        }

        guard let payer = paidBy else {
            errorHandler.handle(.missingPerson)
            return
        }

        do {
            if let existing = expenseToEdit {
                try expenseManager.updateExpense(
                    existing,
                    name: name,
                    amount: amount,
                    currency: currency,
                    group: group,
                    paidBy: payer,
                    splitType: splitType,
                    participants: sortedParticipants,
                    exactAmounts: splitType == .exact ? exactAmounts : nil
                )
            } else {
                _ = try expenseManager.createExpense(
                    name: name,
                    amount: amount,
                    currency: currency,
                    group: group,
                    paidBy: payer,
                    splitType: splitType,
                    participants: sortedParticipants,
                    exactAmounts: splitType == .exact ? exactAmounts : nil
                )
            }
            onSave?()
            dismiss()
        } catch let error as AppError {
            errorHandler.handle(error)
        } catch {
            errorHandler.handleCoreDataError(error, operation: "save")
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}
