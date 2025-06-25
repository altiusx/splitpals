//
//  GradientColorPicker.swift
//  SplitPals
//
//  Created by Chris Choong on 26/6/25.
//
import SwiftUI

struct GradientColorPicker: View {
    @Binding var selectedGradientName: String
    let gradients: [AppCardGradient]

    var body: some View {
        HStack {
            ForEach(gradients, id: \.name) { gradient in
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: gradient.colors),
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    if selectedGradientName == gradient.name {
                        Circle()
                            .stroke(Color.gray, lineWidth: 3)
                            .frame(width: 44, height: 44)
                    }
                }
                .contentShape(Circle())
                .onTapGesture { selectedGradientName = gradient.name }
                .frame(maxWidth: .infinity) // evenly spaces
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}


