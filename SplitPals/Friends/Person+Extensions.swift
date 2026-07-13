//
//  Person+Extensions.swift
//  SplitPals
//
//  Created by Chris Choong
//

import Foundation

extension Person {
    /// Name shown in lists and summaries, marking the current user.
    var displayName: String {
        if isCurrentUser {
            return "\(name ?? "Me") (Me)"
        }
        return name ?? "Unknown"
    }

    /// First letter of the name, for compact avatar bubbles (e.g. "R" for Raymond).
    var initial: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}
