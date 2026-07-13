//
//  AppCardView.swift
//  SplitPals
//
//  Created by Chris Choong on 25/6/25.
//
import SwiftUI

struct AppCardView: View {
    var icon: String
    var gradientColors: [Color]
    var title: String
    var memberInitials: [String] = []
    var onEdit: (() -> Void)? = nil
    var onAddExpense: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    /// Bubbles shown before collapsing the rest into a "+N" bubble.
    private static let maxVisibleMembers = 3

    /// Overlapping initial bubbles for the group's members, collapsing
    /// beyond `maxVisibleMembers` into a "+N" bubble.
    @ViewBuilder
    private var memberBubbles: some View {
        if !memberInitials.isEmpty {
            let visible = memberInitials.prefix(Self.maxVisibleMembers)
            let overflow = memberInitials.count - visible.count

            HStack(spacing: -8) {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, initial in
                    memberBubble(initial)
                }
                if overflow > 0 {
                    memberBubble("+\(overflow)")
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(memberInitials.count) members")
        }
    }

    private func memberBubble(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(gradientColors.first ?? .primary)
            .frame(width: 24, height: 24)
            // Opaque fill so overlapping bubbles occlude cleanly; the
            // gradient ring separates them from each other and the card.
            .background(.white, in: Circle())
            .overlay(Circle().strokeBorder(
                LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            ))
    }

    @ViewBuilder
    private func cardContextMenu() -> some View {
        if let onEdit, let onAddExpense, let onDelete {
            Button(action: onEdit) {
                Label("Edit Group", systemImage: "pencil")
            }
            Button(action: onAddExpense) {
                Label("Add Expense", systemImage: "plus")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete Group", systemImage: "trash")
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).font(.title)
                    Spacer()
                    memberBubbles
                }
                Spacer()
                Text(title)
                    .font(.title2)
                    .bold()
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .padding()
            .foregroundColor(.white)
        }
        // Attach contextMenu to the whole card
        .if(onEdit != nil && onAddExpense != nil && onDelete != nil) { view in
            view.contextMenu { cardContextMenu() }
        }
    }
}

// MARK: - SwiftUI View Modifier to conditionally apply contextMenu
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, apply: (Self) -> Content) -> some View {
        if condition {
            apply(self)
        } else {
            self
        }
    }
}
