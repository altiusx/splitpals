//
//  ExchangeRateService.swift
//  SplitPals
//
//  Created by Chris Choong
//

import Foundation
import os.log

@MainActor
class ExchangeRateService: ObservableObject {
    static let shared = ExchangeRateService()

    @Published var rates: [String: Double] = [:]
    @Published var baseCurrency: String {
        didSet {
            if baseCurrency != oldValue {
                UserDefaults.standard.set(baseCurrency, forKey: homeCurrencyKey)
                rates = [:]
                isLoaded = false
                Task { await fetchRates() }
            }
        }
    }
    @Published var isLoaded = false

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SplitPals", category: "exchangeRates")
    private let cacheKey = "cachedExchangeRates"
    private let cacheTimestampKey = "cachedExchangeRatesTimestamp"
    private let cacheMaxAge: TimeInterval = 86400
    private let homeCurrencyKey = "homeCurrency"

    static var defaultHomeCurrency: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "homeCurrency")
        self.baseCurrency = saved ?? ExchangeRateService.defaultHomeCurrency
        loadFromCache()
    }

    static let supportedCurrencies = [
        "AUD", "CAD", "CHF", "CNY", "EUR", "GBP", "HKD", "IDR", "INR",
        "JPY", "KRW", "MYR", "NZD", "SGD", "THB", "TWD", "USD", "VND"
    ]

    func fetchRates(forceRefresh: Bool = false) async {
        if !forceRefresh && isCacheFresh { return }

        let quotes = Self.supportedCurrencies
            .filter { $0 != baseCurrency }
            .joined(separator: ",")
        let urlString = "https://api.frankfurter.dev/v2/rates?base=\(baseCurrency)&quotes=\(quotes)"
        guard let url = URL(string: urlString) else {
            logger.error("Invalid exchange rate URL")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let entries = try JSONDecoder().decode([RateEntry].self, from: data)
            var fetched: [String: Double] = [baseCurrency: 1.0]
            for entry in entries {
                fetched[entry.quote] = entry.rate
            }
            rates = fetched
            isLoaded = true
            saveToCache()
            logger.info("Fetched \(entries.count) exchange rates for \(self.baseCurrency)")
        } catch {
            logger.error("Failed to fetch exchange rates: \(error.localizedDescription)")
        }
    }

    func convert(amount: Double, from sourceCurrencyCode: String, to targetCurrencyCode: String? = nil) -> Double? {
        let target = targetCurrencyCode ?? baseCurrency
        if sourceCurrencyCode == target { return nil }

        guard let sourceRate = rates[sourceCurrencyCode],
              let targetRate = rates[target],
              sourceRate > 0 else {
            return nil
        }

        return amount * (targetRate / sourceRate)
    }

    func formatConverted(amount: Double, from sourceCurrencyCode: String) -> String? {
        guard let converted = convert(amount: amount, from: sourceCurrencyCode) else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = baseCurrency
        return formatter.string(from: NSNumber(value: converted))
    }

    // MARK: - Cache

    private var isCacheFresh: Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date else { return false }
        return Date().timeIntervalSince(timestamp) < cacheMaxAge && !rates.isEmpty
    }

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(CachedRates.self, from: data),
              cached.base == baseCurrency,
              Set(Self.supportedCurrencies).isSubset(of: Set(cached.rates.keys)) else { return }

        rates = cached.rates
        rates[baseCurrency] = 1.0
        isLoaded = true
        logger.info("Loaded exchange rates from cache")
    }

    private func saveToCache() {
        let cached = CachedRates(base: baseCurrency, rates: rates)
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
        }
    }
}

// MARK: - Models

private struct RateEntry: Decodable {
    let base: String
    let quote: String
    let rate: Double
}

private struct CachedRates: Codable {
    let base: String
    let rates: [String: Double]
}
