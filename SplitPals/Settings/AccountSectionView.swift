//
//  AccountSectionView.swift
//  SplitPals
//
//  Created by Chris Choong
//

import AuthenticationServices
import SwiftUI

/// "Account" section for Settings: Sign in with Apple / Google when signed
/// out, or the connected identity + Sign Out when signed in. This only
/// covers cloud identity — it doesn't sync expense/group data.
struct AccountSectionView: View {
    @ObservedObject private var authService = AuthService.shared
    @State private var isSigningInWithGoogle = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            if let account = authService.cloudAccount {
                signedInRow(for: account)
            } else {
                signInButtons
            }
        } header: {
            Text("Account")
        } footer: {
            if authService.cloudAccount == nil {
                Text("Sign in with Apple or Google to identify yourself with SplitPals.")
            }
        }
        .alert(
            "Sign-In Failed",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var signInButtons: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.signIn) { request in
                authService.prepareAppleSignInRequest(request)
            } onCompletion: { result in
                Task {
                    do {
                        try await authService.completeAppleSignIn(with: result)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)

            googleButton
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .listRowBackground(Color.clear)
    }

    /// Custom button following Google's sign-in branding guidelines
    /// (white background, "G" logo, neutral border) since this flow uses
    /// Supabase-hosted OAuth rather than the native Google Sign-In SDK.
    private var googleButton: some View {
        Button {
            Task {
                isSigningInWithGoogle = true
                defer { isSigningInWithGoogle = false }
                do {
                    try await authService.signInWithGoogle()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image("GoogleLogo")
                    .resizable()
                    .frame(width: 18, height: 18)
                Text("Continue with Google")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(red: 0.26, green: 0.26, blue: 0.26))
                Spacer()
                if isSigningInWithGoogle {
                    ProgressView()
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.86, green: 0.86, blue: 0.86), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isSigningInWithGoogle)
    }

    private func signedInRow(for account: CloudAccount) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: account.provider == "apple" ? "apple.logo" : "person.crop.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name ?? account.email ?? "Signed in")
                        .font(.headline)
                    if let email = account.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                }

                Spacer()

                Text(account.provider.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            Button(role: .destructive) {
                Task {
                    do {
                        try await authService.signOut()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                Text("Sign Out")
            }
        }
        .padding(.vertical, 4)
    }
}
