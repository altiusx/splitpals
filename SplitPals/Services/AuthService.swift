//
//  AuthService.swift
//  SplitPals
//
//  Created by Chris Choong
//

import CoreData
import Foundation

/// Resolves the identity of the person using the app.
@MainActor
protocol AuthProviding {
    /// The signed-in user's Person record, or nil before onboarding.
    func currentUser(in context: NSManagedObjectContext) throws -> Person?
}

/// Stub auth service: the "signed-in user" is the local Person flagged
/// `isCurrentUser`, created during onboarding.
///
/// When Sign in with Apple is adopted, this is where the Apple credential
/// gets exchanged for (or linked to) a Person record — callers only depend
/// on `AuthProviding`, so nothing else changes.
@MainActor
final class AuthService: AuthProviding, ObservableObject {
    static let shared = AuthService()

    func currentUser(in context: NSManagedObjectContext) throws -> Person? {
        try PersonManager(context: context).fetchCurrentUser()
    }
}
