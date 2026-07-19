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
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    @FetchRequest(
        entity: Currency.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Currency.name, ascending: true)]
    ) var currencies: FetchedResults<Currency>

    @FetchRequest(
        entity: Person.entity(),
        sortDescriptors: [],
        predicate: NSPredicate(format: "isCurrentUser == YES")
    ) private var currentUserResults: FetchedResults<Person>

    @State private var isEditingProfile = false

    var body: some View {
        NavigationStack {
            Form {
                profileSection

                AccountSectionView()

                Section {
                    Toggle("Dark Mode", isOn: $forceDarkMode)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("When off, SplitPals follows your device appearance.")
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
                    Text("Other currencies are shown converted to \(exchangeRateService.baseCurrency).")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isEditingProfile) {
                if let user = currentUserResults.first {
                    AddEditFriend(personToEdit: user)
                }
            }
        }
    }

    /// Apple Settings-style header: the user's profile on top, with friend
    /// management directly beneath it.
    private var profileSection: some View {
        Section {
            if let user = currentUserResults.first {
                Button {
                    isEditingProfile = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: user.icon ?? "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name ?? "Me")
                                .font(.title3)
                                .bold()
                                .foregroundStyle(Color.primary)
                            Text("Name and avatar")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityLabel("Edit profile")
            }

            NavigationLink {
                FriendsListView()
            } label: {
                Label("Manage Friends", systemImage: "person.2")
            }
        }
    }
}
