//
//  ReceiptSheet.swift
//  SplitPals
//
//  Created by Chris Choong on 22/6/25.
//
import Foundation
import CoreData

enum ReceiptSheet: Identifiable {
    case add
    case edit(NSManagedObjectID)
    
    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let objectID):
            return objectID.uriRepresentation().absoluteString
        }
    }
}
