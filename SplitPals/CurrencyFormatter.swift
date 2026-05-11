//
//  CurrencyFormatter.swift
//  SplitPals
//
//  Created by Chris Choong
//

import Foundation

struct CurrencyFormatter {
    
    // MARK: - Formatting
    
    /// Formats an amount with the given currency
    static func format(amount: Double, currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        
        if let symbol = currency.symbol {
            formatter.currencySymbol = symbol
        }
        
        return formatter.string(from: NSNumber(value: amount))
            ?? "\(currency.symbol ?? "")\(amount)"
    }
    
    // MARK: - Fraction Digits
    
    /// Returns the number of fraction digits for a currency code
    static func fractionDigits(for currencyCode: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.maximumFractionDigits
    }
    
    // MARK: - Raw Amount Conversion
    
    /// Converts a raw integer string (e.g., "1234") to a Double amount based on currency fraction digits
    /// Example: "1234" with USD (2 fraction digits) -> 12.34
    static func convertRawAmount(_ rawAmount: String, currency: Currency) -> Double? {
        guard let rawInt = Int(rawAmount),
              let code = currency.code else { return nil }
        
        let fractionDigits = fractionDigits(for: code)
        let divisor = pow(10.0, Double(fractionDigits))
        return Double(rawInt) / divisor
    }
    
    /// Converts a Double amount to a raw integer string based on currency fraction digits
    /// Example: 12.34 with USD (2 fraction digits) -> "1234"
    static func convertToRawAmount(_ amount: Double, currency: Currency) -> String {
        guard let code = currency.code else { return "0" }
        
        let fractionDigits = fractionDigits(for: code)
        let multiplier = pow(10.0, Double(fractionDigits))
        let rawInt = Int((amount * multiplier).rounded())
        return String(rawInt)
    }
    
    // MARK: - Default Currency
    
    /// Returns the default currency code based on the user's locale
    static func defaultCurrencyCode() -> String {
        return Locale.current.currency?.identifier ?? "USD"
    }
}
