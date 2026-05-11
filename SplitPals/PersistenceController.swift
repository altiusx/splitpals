//
//  PersistenceController.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//
import CoreData
import os.log

class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SplitPals", category: "persistence")
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SplitPalsModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
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
        }
    }
    
    private func seedCurrencies(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Currency> = Currency.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        do {
            let count = try context.count(for: fetchRequest)
            if count > 0 {
                logger.info("Currencies already seeded, skipping")
                return
            }
        } catch {
            logger.error("Failed to check if currencies are seeded: \(error.localizedDescription)")
            return
        }
        
        logger.info("Seeding currencies...")
        
        let defaultCurrencies = [
            ("USD", "$", "US Dollar"),
            ("SGD", "S$", "Singapore Dollar"),
            ("CNY", "CNY", "Chinese Yuan"),
            ("CAD", "C$", "Canadian Dollar"),
            ("AUD", "A$", "Australian Dollar"),
            ("CHF", "CHF", "Swiss Franc"),
            ("HKD", "HK$", "Hong Kong Dollar"),
            ("THB", "฿", "Thai Baht"),
            ("NZD", "NZ$", "New Zealand Dollar"),
            ("INR", "₹", "Indian Rupee"),
            ("BRL", "R$", "Brazilian Real"),
            ("IDR", "Rp", "Indonesian Rupiah"),
            ("MXN", "MX$", "Mexican Peso"),
            ("ILS", "₪", "Israeli New Sheqel"),
            ("TRY", "₺", "Turkish Lira"),
            ("PLN", "zł", "Polish Zloty"),
            ("NTD", "NT$", "Taiwan New Dollar"),
            ("MOP", "MOP$", "Macanese Pataca"),
            ("JPY", "¥", "Japanese Yen"),
            ("GBP", "£", "British Pound"),
            ("EUR", "€", "Euro"),
            ("MYR", "RM", "Malaysian Ringgit")
        ]
        
        for (code, symbol, name) in defaultCurrencies {
            let currency = Currency(context: context)
            currency.code = code
            currency.symbol = symbol
            currency.name = name
        }
        
        do {
            try context.save()
            logger.info("Successfully seeded \(defaultCurrencies.count) currencies")
        } catch {
            logger.error("Failed to seed currencies: \(error.localizedDescription)")
        }
    }
    
    
}
