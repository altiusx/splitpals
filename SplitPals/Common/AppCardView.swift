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
    var onEdit: (() -> Void)? = nil
    var onAddReceipt: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    @ViewBuilder
    private func cardContextMenu() -> some View {
        if let onEdit, let onAddReceipt, let onDelete {
            Button(action: onEdit) {
                Label("Edit Wallet", systemImage: "pencil")
            }
            Button(action: onAddReceipt) {
                Label("Add Receipt", systemImage: "plus")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete Wallet", systemImage: "trash")
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
                    // TODO: in the future, add icons of user account faces
//                    if let onEdit, let onAddReceipt, let onDelete {
//                        Image(systemName: "ellipsis.circle.fill")
//                            .font(.title2)
//                            .foregroundColor(.white.opacity(0.9))
//                            .contextMenu {
//                                cardContextMenu()
//                            }
//                    }
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
        .if(onEdit != nil && onAddReceipt != nil && onDelete != nil) { view in
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
