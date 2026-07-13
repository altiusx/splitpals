//
//  GroupManager.swift
//  SplitPals
//
//  Created by Chris Choong
//

import CoreData
import Foundation

@MainActor
class GroupManager {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Create

    func createGroup(name: String, gradientName: String, icon: String) throws -> ExpenseGroup {
        let group = ExpenseGroup(context: context)
        group.id = UUID()
        group.name = name
        group.gradientName = gradientName
        group.icon = icon
        group.createdAt = Date()

        try context.save()
        return group
    }

    // MARK: - Update

    func updateGroup(_ group: ExpenseGroup, name: String, gradientName: String, icon: String) throws {
        group.name = name
        group.gradientName = gradientName
        group.icon = icon

        try context.save()
    }

    // MARK: - Members

    func updateMembers(_ group: ExpenseGroup, members: [Person]) throws {
        group.members = NSSet(array: members)
        try context.save()
    }

    // MARK: - Delete

    func deleteGroup(_ group: ExpenseGroup) throws {
        context.delete(group)
        try context.save()
    }

    // MARK: - Fetch

    func fetchAllGroups() throws -> [ExpenseGroup] {
        let request = ExpenseGroup.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return try context.fetch(request)
    }
}
