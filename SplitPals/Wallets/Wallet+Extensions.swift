//
//  Wallet+Extensions.swift
//  SplitPals
//
//  Created by Chris Choong on 16/6/25.
//
import Foundation

extension Wallet {
    var receiptsArray: [Receipt] {
        let set = receipt as? Set<Receipt> ?? []
        return set.sorted {
            ($0.timestamp ?? Date()) > ($1.timestamp ?? Date())
        }
    }

    var membersArray: [Person] {
        let set = members as? Set<Person> ?? []
        return set.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
}

