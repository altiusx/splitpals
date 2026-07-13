//
//  ErrorHandler.swift
//  SplitPals
//
//  Created by Chris Choong
//

import Foundation
import SwiftUI
import os.log

/// The Core Data operation that failed, used to pick a user-facing message.
enum CoreDataOperation {
    case save
    case fetch
    case delete
}

enum AppError: LocalizedError {
    case coreDataSaveFailed(Error)
    case coreDataFetchFailed(Error)
    case coreDataDeleteFailed(Error)
    case invalidInput(String)
    case missingCurrency
    case missingGroup
    case missingPerson

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
        case .missingGroup:
            return "Please select a group"
        case .missingPerson:
            return "Please select a person"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .coreDataSaveFailed, .coreDataFetchFailed, .coreDataDeleteFailed:
            return "Please try again. If the problem persists, restart the app."
        case .invalidInput:
            return "Please check your input and try again."
        case .missingCurrency, .missingGroup, .missingPerson:
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
    
    func handleCoreDataError(_ error: Error, operation: CoreDataOperation) {
        logger.error("Core Data error during \(String(describing: operation)): \(error.localizedDescription)")

        let appError: AppError
        switch operation {
        case .save:
            appError = .coreDataSaveFailed(error)
        case .fetch:
            appError = .coreDataFetchFailed(error)
        case .delete:
            appError = .coreDataDeleteFailed(error)
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
