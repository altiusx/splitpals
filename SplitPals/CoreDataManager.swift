//
//  CoreDataManager.swift
//  SplitPals
//
//  Created by Chris Choong
//

import CoreData
import Foundation

@MainActor
class CoreDataManager: ObservableObject {
    let container: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SplitPalsModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure context for better performance
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Save Context
    
    func save() throws {
        guard viewContext.hasChanges else { return }
        try viewContext.save()
    }
    
    // MARK: - Background Context
    
    func performBackgroundTask(_ block: @Sendable @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
}
