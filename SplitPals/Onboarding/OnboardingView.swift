//
//  OnboardingView.swift
//  SplitPals
//
//  Created by Chris Choong
//

import SwiftUI
import CoreData

struct OnboardingView: View {
    @Environment(\.managedObjectContext) var viewContext
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "person.crop.circle.fill"
    @StateObject private var errorHandler = ErrorHandler()
    
    var onComplete: () -> Void
    
    private var personManager: PersonManager {
        PersonManager(context: viewContext)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                Image(systemName: selectedIcon)
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)
                
                Text("Welcome to SplitPals")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("What should we call you?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                TextField("Your name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .padding(.horizontal, 40)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose an avatar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 40)
                    
                    AvatarPicker(selectedIcon: $selectedIcon)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                Button(action: createCurrentUser) {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .errorAlert(errorHandler: errorHandler)
        }
    }
    
    private func createCurrentUser() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        do {
            _ = try personManager.createPerson(
                name: trimmedName,
                icon: selectedIcon,
                isCurrentUser: true
            )
            onComplete()
        } catch {
            errorHandler.handleCoreDataError(error, operation: .save)
        }
    }
}
