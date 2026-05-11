//
//  WalletManager.swift
//  SplitPals
//
//  Created by Chris Choong
//

import CoreData
import Foundation

@MainActor
class WalletManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Create
    
    func createWallet(name: String, gradientName: String, icon: String) throws -> Wallet {
        let wallet = Wallet(context: context)
        wallet.name = name
        wallet.gradientName = gradientName
        wallet.icon = icon
        wallet.createdAt = Date()
        
        try context.save()
        return wallet
    }
    
    // MARK: - Update
    
    func updateWallet(_ wallet: Wallet, name: String, gradientName: String, icon: String) throws {
        wallet.name = name
        wallet.gradientName = gradientName
        wallet.icon = icon
        
        try context.save()
    }
    
    // MARK: - Delete
    
    func deleteWallet(_ wallet: Wallet) throws {
        context.delete(wallet)
        try context.save()
    }
    
    // MARK: - Fetch
    
    func fetchAllWallets() throws -> [Wallet] {
        let request = Wallet.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return try context.fetch(request)
    }
}
