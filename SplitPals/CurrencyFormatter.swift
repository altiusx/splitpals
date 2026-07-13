//
//  CurrencyFormatter.swift
//  SplitPals
//
//  Created by Chris Choong
//

import Foundation

struct CurrencyFormatter {

    // MARK: - Cached Formatters

    /// NumberFormatter is expensive to create, and formatting happens in
    /// list rows and split calculations, so formatters are cached per
    /// currency code + symbol combination.
    private static var formatterCache: [String: NumberFormatter] = [:]
    private static var fractionDigitsCache: [String: Int] = [:]

    private static func formatter(currencyCode: String?, symbol: String? = nil) -> NumberFormatter {
        let cacheKey = "\(currencyCode ?? "")|\(symbol ?? "")"
        if let cached = formatterCache[cacheKey] {
            return cached
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        if let currencyCode {
            formatter.currencyCode = currencyCode
        }
        if let symbol {
            formatter.currencySymbol = symbol
        }
        formatterCache[cacheKey] = formatter
        return formatter
    }

    // MARK: - Formatting

    /// Formats an amount with the given currency
    static func format(amount: Double, currency: Currency) -> String {
        formatter(currencyCode: currency.code, symbol: currency.symbol)
            .string(from: NSNumber(value: amount))
            ?? "\(currency.symbol ?? "")\(amount)"
    }

    /// Formats an amount using only a currency code (locale-default symbol).
    static func format(amount: Double, currencyCode: String) -> String {
        formatter(currencyCode: currencyCode)
            .string(from: NSNumber(value: amount))
            ?? "\(currencyCode) \(amount)"
    }

    // MARK: - Fraction Digits

    /// Returns the number of fraction digits for a currency code
    static func fractionDigits(for currencyCode: String) -> Int {
        if let cached = fractionDigitsCache[currencyCode] {
            return cached
        }
        let digits = formatter(currencyCode: currencyCode).maximumFractionDigits
        fractionDigitsCache[currencyCode] = digits
        return digits
    }

    // MARK: - Raw Amount Conversion

    /// Converts a raw integer string (e.g., "1234") to a Double amount based on fraction digits
    /// Example: "1234" with 2 fraction digits -> 12.34
    static func convertRawAmount(_ rawAmount: String, fractionDigits: Int) -> Double? {
        guard let rawInt = Int(rawAmount) else { return nil }
        let divisor = pow(10.0, Double(fractionDigits))
        return Double(rawInt) / divisor
    }

    /// Converts a raw integer string (e.g., "1234") to a Double amount based on currency fraction digits
    /// Example: "1234" with USD (2 fraction digits) -> 12.34
    static func convertRawAmount(_ rawAmount: String, currency: Currency) -> Double? {
        guard let code = currency.code else { return nil }
        return convertRawAmount(rawAmount, fractionDigits: fractionDigits(for: code))
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
