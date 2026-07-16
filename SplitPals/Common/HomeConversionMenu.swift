//
//  HomeConversionMenu.swift
//  SplitPals
//
//  Created by Chris Choong
//

import SwiftUI

/// Toolbar menu that switches a screen between showing each currency
/// natively and converting everything into the home currency.
struct HomeConversionMenu: View {
    @Binding var convertsToHome: Bool
    let homeCurrency: String

    var body: some View {
        Menu {
            Picker("Currency display", selection: $convertsToHome) {
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
}
