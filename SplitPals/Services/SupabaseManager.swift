//
//  SupabaseManager.swift
//  SplitPals
//
//  Created by Chris Choong
//

import Foundation
import Supabase

/// Shared Supabase client for the whole app.
enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.projectURL,
        supabaseKey: SupabaseConfig.publishableKey
    )
}
