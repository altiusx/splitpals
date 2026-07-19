//
//  AuthService.swift
//  SplitPals
//
//  Created by Chris Choong
//

import AuthenticationServices
import CoreData
import CryptoKit
import Foundation
import Supabase

/// Resolves the identity of the person using the app.
@MainActor
protocol AuthProviding {
    /// The signed-in user's Person record, or nil before onboarding.
    func currentUser(in context: NSManagedObjectContext) throws -> Person?
}

/// The signed-in Supabase identity, if any. Separate from the local `Person`
/// resolved by `AuthProviding` — this only tracks the cloud account used for
/// Sign in with Apple / Google, mirroring the web app's `AuthContext`.
struct CloudAccount: Equatable {
    let id: UUID
    let email: String?
    let name: String?
    let provider: String
}

enum AuthServiceError: LocalizedError {
    case missingAppleIdentityToken
    case missingNonce

    var errorDescription: String? {
        switch self {
        case .missingAppleIdentityToken:
            return "Apple didn't return an identity token."
        case .missingNonce:
            return "Missing sign-in nonce. Please try again."
        }
    }
}

/// The "signed-in user" for split/expense purposes is still the local
/// `Person` flagged `isCurrentUser`, created during onboarding — that part of
/// `AuthProviding` is unchanged. `AuthService` additionally tracks a
/// Supabase-backed cloud account (Sign in with Apple / Google), surfaced in
/// Settings, against the same Supabase project the web app uses.
@MainActor
final class AuthService: AuthProviding, ObservableObject {
    static let shared = AuthService()

    @Published private(set) var cloudAccount: CloudAccount?

    private var currentAppleNonce: String?
    private var authStateTask: Task<Void, Never>?

    private init() {
        cloudAccount = Self.account(from: SupabaseManager.client.auth.currentSession?.user)
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await (_, session) in SupabaseManager.client.auth.authStateChanges {
                self.cloudAccount = Self.account(from: session?.user)
            }
        }
    }

    func currentUser(in context: NSManagedObjectContext) throws -> Person? {
        try PersonManager(context: context).fetchCurrentUser()
    }

    // MARK: - Sign in with Apple

    /// Call from `SignInWithAppleButton`'s `onRequest` closure.
    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let rawNonce = Self.randomNonceString()
        currentAppleNonce = rawNonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(rawNonce)
    }

    /// Call from `SignInWithAppleButton`'s `onCompletion` closure.
    func completeAppleSignIn(with result: Result<ASAuthorization, Error>) async throws {
        let authorization = try result.get()
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthServiceError.missingAppleIdentityToken
        }
        guard let rawNonce = currentAppleNonce else {
            throw AuthServiceError.missingNonce
        }
        currentAppleNonce = nil

        _ = try await SupabaseManager.client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: rawNonce)
        )
    }

    // MARK: - Google (Supabase-hosted OAuth)

    /// Opens Google's consent screen in a system browser sheet
    /// (`ASWebAuthenticationSession`, managed internally by supabase-swift)
    /// and redirects back via `SupabaseConfig.oauthRedirectURL`. Reuses the
    /// same Google OAuth client already configured for the web app in the
    /// Supabase dashboard — no separate Google Cloud project needed.
    func signInWithGoogle() async throws {
        _ = try await SupabaseManager.client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: SupabaseConfig.oauthRedirectURL
        )
    }

    // MARK: - Sign out

    func signOut() async throws {
        try await SupabaseManager.client.auth.signOut()
    }

    // MARK: - Helpers

    private static func account(from user: User?) -> CloudAccount? {
        guard let user else { return nil }
        let metadata = user.userMetadata
        let name = metadata["full_name"]?.stringValue ?? metadata["name"]?.stringValue
        let provider = user.appMetadata["provider"]?.stringValue ?? "unknown"
        return CloudAccount(id: user.id, email: user.email, name: name, provider: provider)
    }

    /// Generates the raw nonce passed to Apple; its SHA256 hash goes on the
    /// request, and the raw value is later handed to Supabase to verify the
    /// identity token actually corresponds to this sign-in attempt.
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(status == errSecSuccess, "Unable to generate a secure nonce.")

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
