//
//  SupabaseConfig.swift
//  SplitPals
//
//  Created by Chris Choong
//

import Foundation

/// Points the app at the same Supabase project used by the SplitPals web app,
/// so an account signed in on either platform resolves to the same user.
///
/// The publishable key is safe to ship in client code — like a web anon key,
/// it only grants what Row Level Security policies on the project allow.
enum SupabaseConfig {
    static let projectURL = URL(string: "https://uinzggshjpornrtcneso.supabase.co")!
    static let publishableKey = "sb_publishable_BShVhNVxraOwptS08DpeVw_a4gdGefP"

    /// Custom scheme ASWebAuthenticationSession redirects back into the app
    /// on after a provider (e.g. Google) finishes in the browser. Must be
    /// added to this Supabase project's Auth > URL Configuration allow list.
    static let oauthRedirectURL = URL(string: "com.chrischoong.splitpals://auth-callback")!
}
