//
//  ProfileView.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//


// ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var state: AppState

    var canContinue: Bool {
        !state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !state.placeOfBirth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Your Details") {
                TextField("Name", text: $state.name)
                    .textContentType(.name)

                Picker("Gender", selection: $state.gender) {
                    ForEach(Gender.allCases) { g in
                        Text(g.rawValue).tag(g)
                    }
                }

                DatePicker("Date of Birth", selection: $state.dob, displayedComponents: .date)
                DatePicker("Time of Birth", selection: $state.timeOfBirth, displayedComponents: .hourAndMinute)

                TextField("Place of Birth (City, Country)", text: $state.placeOfBirth)
                    .textContentType(.addressCity)
            }

            Section {
                NavigationLink("Continue") {
                    FocusView()
                }
                .disabled(!canContinue)
            } footer: {
                Text("Enter at least your name and place of birth to continue.")
            }
        }
        .navigationTitle("Profile")
    }
}