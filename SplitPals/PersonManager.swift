//
//  PersonManager.swift
//  SplitPals
//
//  Created by Chris Choong
//

import CoreData
import Foundation

@MainActor
class PersonManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Create
    
    func createPerson(name: String, icon: String, isCurrentUser: Bool = false) throws -> Person {
        let person = Person(context: context)
        person.id = UUID()
        person.name = name
        person.icon = icon
        person.isCurrentUser = isCurrentUser
        person.createdAt = Date()
        
        try context.save()
        return person
    }
    
    // MARK: - Update
    
    func updatePerson(_ person: Person, name: String, icon: String) throws {
        person.name = name
        person.icon = icon
        
        try context.save()
    }
    
    // MARK: - Delete
    
    func deletePerson(_ person: Person) throws {
        context.delete(person)
        try context.save()
    }
    
    // MARK: - Fetch
    
    func fetchAllPersons() throws -> [Person] {
        let request = Person.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Person.name, ascending: true)]
        return try context.fetch(request)
    }
    
    func fetchCurrentUser() throws -> Person? {
        let request = Person.fetchRequest()
        request.predicate = NSPredicate(format: "isCurrentUser == YES")
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
