//
//  ExpenseRow.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//

import SwiftUI

struct ReceiptRow: View {
    let receipt: Receipt
    
    var body: some View {
        HStack {
            Text(receipt.name ?? "")
            Spacer()
            Text("\(receipt.currency?.symbol ?? "")\(String(format: "%.2f", receipt.amount))")
        }
    }
}

