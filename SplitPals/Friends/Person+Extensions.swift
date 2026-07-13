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
}
