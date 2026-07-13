//
//  AvatarPicker.swift
//  SplitPals
//
//  Created by Chris Choong
//

import SwiftUI

/// Grid of avatar symbols used when creating or editing a person.
struct AvatarPicker: View {
    @Binding var selectedIcon: String

    static let avatarIcons = [
        "person.crop.circle.fill",
        "person.fill",
        "figure.stand",
        "face.smiling.inverse",
        "star.circle.fill",
        "heart.circle.fill",
        "bolt.circle.fill",
        "flame.circle.fill",
        "leaf.circle.fill",
        "moon.circle.fill",
        "sun.max.circle.fill",
        "sparkles"
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
            ForEach(Self.avatarIcons, id: \.self) { icon in
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        Circle()
                            .stroke(selectedIcon == icon ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .onTapGesture {
                        selectedIcon = icon
                    }
                    .accessibilityLabel(Text(icon))
            }
        }
    }
}
