//
//  ReceiptManager.swift
//  SplitPals
//
//  Created by Chris Choong
//

import CoreData
import Foundation

@MainActor
class ReceiptManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Create
    
    func createReceipt(
        name: String,
        amount: Double,
        currency: Currency,
        wallet: Wallet
    ) throws -> Receipt {
        let receipt = Receipt(context: context)
        receipt.name = name
        receipt.amount = amount
        receipt.currency = currency
        receipt.wallet = wallet
        receipt.timestamp = Date()
        
        try context.save()
        return receipt
    }
    
    // MARK: - Update
    
    func updateReceipt(
        _ receipt: Receipt,
        name: String,
        amount: Double,
        currency: Currency,
        wallet: Wallet
    ) throws {
        receipt.name = name
        receipt.amount = amount
        receipt.currency = currency
        receipt.wallet = wallet
        
        try context.save()
    }
    
    // MARK: - Delete
    
    func deleteReceipt(_ receipt: Receipt) throws {
        context.delete(receipt)
        try context.save()
    }
    
    // MARK: - Fetch
    
    func fetchReceipts(for wallet: Wallet?) throws -> [Receipt] {
        let request = Receipt.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        if let wallet = wallet {
            request.predicate = NSPredicate(format: "wallet == %@", wallet)
        } else {
            request.predicate = NSPredicate(format: "wallet == nil")
        }
        
        return try context.fetch(request)
    }
}
