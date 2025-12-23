//
//  AppState.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//
// AppState.swift
import Foundation
import Combine

enum Gender: String, CaseIterable, Identifiable, Codable {
    case male = "Male"
    case female = "Female"
    case nonBinary = "Non-binary"
    case preferNotToSay = "Prefer not to say"

    var id: String { rawValue }
}

enum FocusArea: String, CaseIterable, Identifiable, Codable {
    case career = "Career"
    case relationships = "Relationships"
    case wealth = "Wealth"
    case health = "Health"

    var id: String { rawValue }
    var systemHint: String {
        switch self {
        case .career: return "Focus on career path, leadership, timing of opportunities, and work relationships."
        case .relationships: return "Focus on relationships, communication patterns, compatibility, and emotional well-being."
        case .wealth: return "Focus on finances, risk, long-term planning, and money habits."
        case .health: return "Focus on wellness routines, stress patterns, and sustainable health habits."
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    // Screen 1
    @Published var name: String = ""
    @Published var gender: Gender = .preferNotToSay
    @Published var dob: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @Published var placeOfBirth: String = ""
    @Published var timeOfBirth: Date = Date()

    // Screen 2
    @Published var focusArea: FocusArea? = nil

    // MARK: - Persistence
    private let profileDefaultsKey = "AppState.profile"

    private struct PersistedProfile: Codable {
        var name: String
        var gender: Gender
        var dob: Date
        var placeOfBirth: String
        var timeOfBirth: Date
        var focusArea: FocusArea?
    }

    init() {
        loadProfile()
    }

    func saveProfile() {
        let profile = PersistedProfile(
            name: name,
            gender: gender,
            dob: dob,
            placeOfBirth: placeOfBirth,
            timeOfBirth: timeOfBirth,
            focusArea: focusArea
        )
        do {
            let data = try JSONEncoder().encode(profile)
            UserDefaults.standard.set(data, forKey: profileDefaultsKey)
        } catch {
            // Silently ignore encoding errors in production
            // print("Failed to save profile: \(error)")
        }
    }

    func resetProfile() {
        // Remove any persisted profile first
        UserDefaults.standard.removeObject(forKey: profileDefaultsKey)

        // Reset in-memory values
        name = ""
        gender = .preferNotToSay
        dob = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        placeOfBirth = ""
        timeOfBirth = Date()
        focusArea = nil
    }

    private func loadProfile() {
        guard let data = UserDefaults.standard.data(forKey: profileDefaultsKey) else { return }
        do {
            let decoded = try JSONDecoder().decode(PersistedProfile.self, from: data)
            name = decoded.name
            gender = decoded.gender
            dob = decoded.dob
            placeOfBirth = decoded.placeOfBirth
            timeOfBirth = decoded.timeOfBirth
            focusArea = decoded.focusArea
        } catch {
            // print("Failed to load profile: \(error)")
        }
    }

    // Optional: keep a stable “profile summary” for prompt building
    func profileSummary() -> String {
        let dobFmt = DateFormatter()
        dobFmt.dateStyle = .medium
        dobFmt.timeStyle = .none

        let tobFmt = DateFormatter()
        tobFmt.dateStyle = .none
        tobFmt.timeStyle = .short

        return """
        Name: \(name.isEmpty ? "Unknown" : name)
        Gender: \(gender.rawValue)
        Date of Birth: \(dobFmt.string(from: dob))
        Time of Birth: \(tobFmt.string(from: timeOfBirth))
        Place of Birth: \(placeOfBirth.isEmpty ? "Unknown" : placeOfBirth)
        Focus Area: \(focusArea?.rawValue ?? "Not selected")
        """
    }
}
