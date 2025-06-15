//
//  ExpenseRow.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//

import SwiftUI

struct ExpenseRow: View {
    let name: String
    let amount: Double
    
    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(String(format: "$%.2f", amount))
        }
    }
}

