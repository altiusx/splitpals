//
//  PersistenceController.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//
import CoreData
import os.log

/// The app's persistent container type.
///
/// Swap this to `NSPersistentCloudKitContainer` when iCloud sync is enabled —
/// the rest of the stack is already configured with CloudKit-compatible
/// patterns (history tracking, remote change notifications, no uniqueness
/// constraints, optional attributes with defaults).
typealias AppPersistentContainer = NSPersistentContainer

class PersistenceController {
    static let shared = PersistenceController()
    let container: AppPersistentContainer

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SplitPals", category: "persistence")

    init(inMemory: Bool = false) {
        container = AppPersistentContainer(name: "SplitPalsModel")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        // CloudKit-compatible store options. NSPersistentCloudKitContainer
        // requires persistent history tracking; enabling it now keeps the
        // local store ready for the swap.
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        // Configure for better performance and merge behavior
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        container.loadPersistentStores { description, error in
            if let error = error {
                // Log the error before crashing in debug, or handle gracefully in production
                self.logger.critical("Core Data failed to load: \(error.localizedDescription)")
                fatalError("Core Data error: \(error.localizedDescription)")
            }

            self.logger.info("Core Data store loaded successfully")
            self.seedCurrencies(context: self.container.viewContext)
            self.backfillIdentifiers(context: self.container.viewContext)
        }
    }

    private func seedCurrencies(context: NSManagedObjectContext) {
        let defaultCurrencies = [
            ("AUD", "A$", "Australian Dollar"),
            ("CAD", "C$", "Canadian Dollar"),
            ("CHF", "CHF", "Swiss Franc"),
            ("CNY", "CNY", "Chinese Yuan"),
            ("EUR", "€", "Euro"),
            ("GBP", "£", "British Pound"),
            ("HKD", "HK$", "Hong Kong Dollar"),
            ("IDR", "Rp", "Indonesian Rupiah"),
            ("INR", "₹", "Indian Rupee"),
            ("JPY", "¥", "Japanese Yen"),
            ("KRW", "₩", "South Korean Won"),
            ("MYR", "RM", "Malaysian Ringgit"),
            ("NZD", "NZ$", "New Zealand Dollar"),
            ("SGD", "S$", "Singapore Dollar"),
            ("THB", "฿", "Thai Baht"),
            ("TWD", "NT$", "Taiwan Dollar"),
            ("USD", "$", "US Dollar"),
            ("VND", "₫", "Vietnamese Dong")
        ]

        let validCodes = Set(defaultCurrencies.map { $0.0 })

        let fetchRequest: NSFetchRequest<Currency> = Currency.fetchRequest()
        var existingByCode: [String: Currency] = [:]
        do {
            let existing = try context.fetch(fetchRequest)
            for currency in existing {
                if let code = currency.code {
                    existingByCode[code] = currency
                }
            }
        } catch {
            logger.error("Failed to fetch existing currencies: \(error.localizedDescription)")
        }

        var addedCount = 0
        for (code, symbol, name) in defaultCurrencies {
            if existingByCode[code] == nil {
                let currency = Currency(context: context)
                currency.id = UUID()
                currency.code = code
                currency.symbol = symbol
                currency.name = name
                existingByCode[code] = currency
                addedCount += 1
            }
        }

        var removedCount = 0
        for (code, currency) in existingByCode where !validCodes.contains(code) {
            context.delete(currency)
            removedCount += 1
        }

        guard addedCount > 0 || removedCount > 0 else {
            logger.info("All currencies already up to date")
            return
        }

        do {
            try context.save()
            logger.info("Currencies updated: \(addedCount) added, \(removedCount) removed")
        } catch {
            logger.error("Failed to update currencies: \(error.localizedDescription)")
        }
    }

    /// Assigns a UUID to any row migrated from an older model version where
    /// the `id` attribute did not exist yet.
    private func backfillIdentifiers(context: NSManagedObjectContext) {
        let entityNames = ["Currency", "Expense", "ExpenseGroup", "ExpenseSplit", "Person"]
        var backfilledCount = 0

        for entityName in entityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = NSPredicate(format: "id == nil")
            do {
                let objects = try context.fetch(request)
                for object in objects {
                    object.setValue(UUID(), forKey: "id")
                    backfilledCount += 1
                }
            } catch {
                logger.error("Failed to backfill ids for \(entityName): \(error.localizedDescription)")
            }
        }

        guard backfilledCount > 0 else { return }

        do {
            try context.save()
            logger.info("Backfilled \(backfilledCount) missing ids")
        } catch {
            logger.error("Failed to save backfilled ids: \(error.localizedDescription)")
        }
    }
}
