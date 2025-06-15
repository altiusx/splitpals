//
//  PersistenceController.swift
//  SplitPals
//
//  Created by Chris Choong on 15/6/25.
//
import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SplitPalsModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
            self.seedCurrencies(context: self.container.viewContext)
        }
    }
    
    private func seedCurrencies(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Currency> = Currency.fetchRequest()
        fetchRequest.fetchLimit = 1
        if (try? context.count(for: fetchRequest)) ?? 0 > 0 {
            return // already seeded currencies
        }
        
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
            ("BRB", "R$", "Brazilian Real"),
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
        try? context.save()
    }
    
    
}
