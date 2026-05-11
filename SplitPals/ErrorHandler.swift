//
//  ErrorHandler.swift
//  SplitPals
//
//  Created by Chris Choong
//

import Foundation
import SwiftUI
import os.log

enum AppError: LocalizedError {
    case coreDataSaveFailed(Error)
    case coreDataFetchFailed(Error)
    case coreDataDeleteFailed(Error)
    case invalidInput(String)
    case missingCurrency
    case missingWallet
    
    var errorDescription: String? {
        switch self {
        case .coreDataSaveFailed:
            return "Failed to save your data"
        case .coreDataFetchFailed:
            return "Failed to load your data"
        case .coreDataDeleteFailed:
            return "Failed to delete"
        case .invalidInput(let message):
            return message
        case .missingCurrency:
            return "Please select a currency"
        case .missingWallet:
            return "Please select a wallet"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .coreDataSaveFailed, .coreDataFetchFailed, .coreDataDeleteFailed:
            return "Please try again. If the problem persists, restart the app."
        case .invalidInput:
            return "Please check your input and try again."
        case .missingCurrency, .missingWallet:
            return "Please make a selection and try again."
        }
    }
}

@MainActor
class ErrorHandler: ObservableObject {
    @Published var currentError: AppError?
    @Published var showError = false
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SplitPals", category: "errors")
    
    func handle(_ error: AppError) {
        logger.error("\(error.localizedDescription)")
        currentError = error
        showError = true
    }
    
    func handleCoreDataError(_ error: Error, operation: String) {
        logger.error("Core Data error during \(operation): \(error.localizedDescription)")
        
        let appError: AppError
        switch operation {
        case "save":
            appError = .coreDataSaveFailed(error)
        case "fetch":
            appError = .coreDataFetchFailed(error)
        case "delete":
            appError = .coreDataDeleteFailed(error)
        default:
            appError = .coreDataSaveFailed(error)
        }
        
        handle(appError)
    }
}

// MARK: - View Extension for Error Handling

extension View {
    func errorAlert(errorHandler: ErrorHandler) -> some View {
        alert("Error", isPresented: Binding(
            get: { errorHandler.showError },
            set: { errorHandler.showError = $0 }
        ), presenting: errorHandler.currentError) { error in
            Button("OK", role: .cancel) {
                errorHandler.showError = false
            }
        } message: { error in
            VStack {
                if let description = error.errorDescription {
                    Text(description)
                }
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                }
            }
        }
    }
}
