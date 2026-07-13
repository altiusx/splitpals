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
    let container: AppPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        container = AppPersistentContainer(name: "SplitPalsModel")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
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
