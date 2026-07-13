//
//  SettingsView.swift
//  SplitPals
//
//  Created by Chris Choong
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @AppStorage("forceDarkMode") private var forceDarkMode = false
    @AppStorage("settleUpUsesHomeCurrency") private var settleUpUsesHomeCurrency = false
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    @FetchRequest(
        entity: Currency.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Currency.name, ascending: true)]
    ) var currencies: FetchedResults<Currency>

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Dark Mode", isOn: $forceDarkMode)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Turn on dark mode to always display in a dark appearance. Turning it off will follow system settings.")
                }

                Section {
                    Picker("Home Currency", selection: Binding(
                        get: { exchangeRateService.baseCurrency },
                        set: { exchangeRateService.baseCurrency = $0 }
                    )) {
                        ForEach(currencies, id: \.self) { currency in
                            Text("\(currency.code ?? "") — \(currency.name ?? "")")
                                .tag(currency.code ?? "")
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Currency")
                } footer: {
                    Text("Receipts in other currencies will show converted amounts in \(exchangeRateService.baseCurrency).")
                }

                Section {
                    Picker("Settle Up In", selection: $settleUpUsesHomeCurrency) {
                        Text("Group's Currency").tag(false)
                        Text("Home Currency").tag(true)
                    }
                } header: {
                    Text("Settle Up")
                } footer: {
                    Text(settleUpUsesHomeCurrency
                         ? "Settle up starts in your home currency, \(exchangeRateService.baseCurrency). You can still switch currencies on the settle up screen."
                         : "Settle up starts in the currency the group's expenses use most. You can still switch currencies on the settle up screen.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
