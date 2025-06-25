//
//  IconColorPickerSheet.swift
//  SplitPals
//
//  Created by Chris Choong on 25/6/25.
//
import SwiftUI

struct IconPicker: View {
    @Binding var selectedSymbol: String
    @State private var symbolSearch: String = ""

    let categories: [String: [String]]
    let gridColumns = [
        GridItem(.adaptive(minimum: 44, maximum: 64), spacing: 0)
    ]

    var filteredSymbols: [String: [String]] {
        if symbolSearch.isEmpty {
            return categories
        } else {
            return categories.mapValues { $0.filter { $0.localizedCaseInsensitiveContains(symbolSearch) } }
                .filter { !$0.value.isEmpty }
        }
    }

    var body: some View {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search Symbols", text: $symbolSearch)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            )
            .padding()
            
            // Icons
            ScrollView {
                if symbolSearch.isEmpty {
                    ForEach(filteredSymbols.keys.sorted(), id: \.self) { category in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(category)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.top, 12)
                            LazyVGrid(columns: gridColumns, spacing: 12) {
                                ForEach(filteredSymbols[category]!, id: \.self) { symbolName in
                                    symbolIcon(symbolName)
                                }
                            }
                            .padding(.bottom, 12)
                        }
                    }
                } else {
                    // Flat grid for search
                    let allMatching = filteredSymbols.values.flatMap { $0 }
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(allMatching, id: \.self) { symbolName in
                            symbolIcon(symbolName)
                        }
                    }
                }
            }
        
//        .background(
//            RoundedRectangle(cornerRadius: 28, style: .continuous)
//                .fill(Color(UIColor.systemBackground))
//        )
    }

    @ViewBuilder
    func symbolIcon(_ symbolName: String) -> some View {
        Image(systemName: symbolName)
            .font(.title2)
            .foregroundColor(selectedSymbol == symbolName ? .accentColor : .primary)
            .frame(width: 44, height: 44)
            .background(
                Circle().fill(selectedSymbol == symbolName ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .onTapGesture { selectedSymbol = symbolName }
            .accessibilityLabel(Text(symbolName))
    }
}
