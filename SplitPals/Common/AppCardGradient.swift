//
//  AppCardGradient.swift
//  SplitPals
//
//  Created by Chris Choong on 25/6/25.
//
import SwiftUI

struct AppCardGradient {
    let name: String
    let colors: [Color]
}

let cardGradients: [AppCardGradient] = [
    .init(name: "Sunset", colors: [Color(red:1.0, green:0.5, blue:0.6), Color(red:1.0, green:0.7, blue:0.5)]),    // Pink-Orange
    .init(name: "Ocean", colors: [Color(red:0.3, green:0.7, blue:1.0), Color(red:0.2, green:0.4, blue:1.0)]),     // Blue gradient
    .init(name: "Violet", colors: [Color(red:0.8, green:0.5, blue:1.0), Color(red:0.5, green:0.2, blue:0.7)]),    // Purple
    .init(name: "Lime", colors: [Color(red:0.20, green:0.80, blue:0.44),Color(red: 0.13, green: 0.65, blue: 0.38)]),      // Green
    .init(name: "Bubblegum", colors: [Color(red:1.0, green:0.7, blue:1.0), Color(red:1.0, green:0.5, blue:0.7)]), // Pink
    .init(name: "Lavender", colors: [Color(red:0.85, green:0.8, blue:1.0), Color(red:0.68, green:0.5, blue:0.98)]) // Light purple
]
