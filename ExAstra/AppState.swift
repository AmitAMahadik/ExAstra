//
//  AppState.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//
// AppState.swift
import Foundation
import Combine
import SwiftOpenAI

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
    private var isRestoringProfile = false
    
    // MARK: - Deterministic Lunar Sign via Swiss Ephemeris MCP

    private let swissMcp = SwissEphemerisMCPClient(
        baseURL: URL(string: "https://conapp-exastra.yellowrock-7298f3d8.westus.azurecontainerapps.io/")!
    )

    @Published var lunarSignDeterministic: String = "—"
    @Published var moonLongitudeDeterministic: Double? = nil
    @Published var lunarSignDeterministicError: String? = nil
    @Published var isRefreshingLunarSignDeterministic: Bool = false

    @Published var name: String = "" {
        didSet { guard !isRestoringProfile else { return }; saveProfile() }
    }
    @Published var gender: Gender = .preferNotToSay {
        didSet { guard !isRestoringProfile else { return }; saveProfile() }
    }
    @Published var dob: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date() {
        didSet { guard !isRestoringProfile else { return }; saveProfile() }
    }
    @Published var placeOfBirth: String = "" {
        didSet { guard !isRestoringProfile else { return }; saveProfile() }
    }
    // Time of Birth stored as pure clock components (time-only)
    @Published var tobHour: Int = 0 {
        didSet { guard !isRestoringProfile else { return }; saveProfile() }
    }
    @Published var tobMinute: Int = 0 {
        didSet { guard !isRestoringProfile else { return }; saveProfile() }
    }
    @Published var tobSecond: Int = 0 {
        didSet { guard !isRestoringProfile else { return }; saveProfile() }
    }

    /// DatePicker bridge only (stable reference date in UTC)
    var timeOfBirthPickerDate: Date {
        get { Self.dateFromHMSUTC(hour: tobHour, minute: tobMinute, second: tobSecond) }
        set {
            let hms = Self.hmsFromDateUTC(newValue)
            tobHour = hms.h
            tobMinute = hms.m
            tobSecond = hms.s
        }
    }

    // Validated birth location/timezone (set after place validation in ProfileView)
    @Published var birthLatitude: Double? = nil {
        didSet { guard !isRestoringProfile else { return }; saveProfile() }
    }
    @Published var birthLongitude: Double? = nil {
        didSet { guard !isRestoringProfile else { return }; saveProfile() }
    }
    @Published var birthTimeZoneIdentifier: String? = nil {
        didSet { guard !isRestoringProfile else { return }; saveProfile() }
    }

    // Screen 2
    @Published var focusArea: FocusArea? = nil {
        didSet { guard !isRestoringProfile else { return }; saveProfile() }
    }

    // MARK: - Persistence
    private let profileDefaultsKey = "AppState.profile"

    private struct PersistedProfile: Codable {
        var name: String
        var gender: Gender

        // DOB as date-only components (no timezone drift)
        var dobYear: Int
        var dobMonth: Int
        var dobDay: Int

        var placeOfBirth: String

        // TOB as time-only components (no timezone drift)
        var tobHour: Int
        var tobMinute: Int
        var tobSecond: Int

        var focusArea: FocusArea?

        var birthLatitude: Double?
        var birthLongitude: Double?
        var birthTimeZoneIdentifier: String?
    }
    

    init() {
        loadProfile()
    }

    func saveProfile() {
        let ymd = Self.ymdFromDateUTC(dob)

        let profile = PersistedProfile(
            name: name,
            gender: gender,
            dobYear: ymd.y,
            dobMonth: ymd.m,
            dobDay: ymd.d,
            placeOfBirth: placeOfBirth,
            tobHour: tobHour,
            tobMinute: tobMinute,
            tobSecond: tobSecond,
            focusArea: nil, // focusArea
            birthLatitude: birthLatitude,
            birthLongitude: birthLongitude,
            birthTimeZoneIdentifier: birthTimeZoneIdentifier
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

        isRestoringProfile = true
        defer { isRestoringProfile = false }

        // Reset in-memory values
        name = ""
        gender = .preferNotToSay
        let now = Date()
        let ymd = Self.ymdFromDateUTC(now)
        dob = Self.dateFromYMDUTC(year: ymd.y - 30, month: ymd.m, day: ymd.d)
        placeOfBirth = ""
        tobHour = 12
        tobMinute = 0
        tobSecond = 0
        focusArea = nil
        birthLatitude = nil
        birthLongitude = nil
        birthTimeZoneIdentifier = nil

        // Persist the cleared defaults
        saveProfile()
    }

    private func loadProfile() {
        guard let data = UserDefaults.standard.data(forKey: profileDefaultsKey) else { return }
        do {
            let decoded = try JSONDecoder().decode(PersistedProfile.self, from: data)

            isRestoringProfile = true
            defer { isRestoringProfile = false }

            name = decoded.name
            gender = decoded.gender
            dob = Self.dateFromYMDUTC(year: decoded.dobYear, month: decoded.dobMonth, day: decoded.dobDay)
            placeOfBirth = decoded.placeOfBirth
            tobHour = decoded.tobHour
            tobMinute = decoded.tobMinute
            tobSecond = decoded.tobSecond
            focusArea = decoded.focusArea
            birthLatitude = decoded.birthLatitude
            birthLongitude = decoded.birthLongitude
            birthTimeZoneIdentifier = decoded.birthTimeZoneIdentifier
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
        Time of Birth (local): \(String(format: "%02d:%02d", tobHour, tobMinute))
        Place of Birth: \(placeOfBirth.isEmpty ? "Unknown" : placeOfBirth)
        Birth Timezone: \(birthTimeZoneIdentifier ?? "Unknown")
        Birth Coordinates: \((birthLatitude != nil && birthLongitude != nil) ? String(format: "%.5f, %.5f", birthLatitude!, birthLongitude!) : "Unknown")
        Birth Moment (UTC): \((try? birthMomentUTCISO8601()) ?? "Unknown")
        Focus Area: \(focusArea?.rawValue ?? "Not selected")
        """
    }

    /// Deterministically computes the Lunar Sign (Moon sign) using the hosted Swiss Ephemeris MCP server.
    /// Requires validated birth timezone + coordinates.
    func refreshDeterministicLunarSign() async {
        isRefreshingLunarSignDeterministic = true
        lunarSignDeterministicError = nil
        defer { isRefreshingLunarSignDeterministic = false }

        do {
            guard let lat = birthLatitude, let lon = birthLongitude else {
                lunarSignDeterministicError = "Validate place of birth to determine birth coordinates before calculating Lunar Sign."
                return
            }

            // Uses your existing, correct UTC conversion logic (dob + timeOfBirth + birthTimeZoneIdentifier)
            let birthUTC = try birthMomentUTC()

            let moon = try await swissMcp.fetchMoonInfo(
                datetimeUTC: birthUTC,
                latitude: lat,
                longitude: lon
            )

            lunarSignDeterministic = moon.sign
            moonLongitudeDeterministic = moon.longitude
        } catch {
            // Optional: If session expires, one retry pattern:
            // swissMcp.resetSession()
            // then retry once.
            lunarSignDeterministicError = String(describing: error)
        }
    }
    
    
    
    /// Combines `dob` (date-only) and `timeOfBirth` (time-only) into an absolute moment in time using the validated birth timezone,
    /// then returns that moment as a UTC Date.
    func birthMomentUTC() throws -> Date {
        guard let tzId = birthTimeZoneIdentifier,
              let birthTZ = TimeZone(identifier: tzId) else {
            throw NSError(domain: "BirthTime", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Validate place of birth to determine the correct timezone before calculating UTC birth time."
            ])
        }

        // Treat DOB as civil Y/M/D (avoid UTC shifting)
        let ymd = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: dob)

        var birthCal = Calendar(identifier: .gregorian)
        birthCal.timeZone = birthTZ

        var comps = DateComponents()
        comps.calendar = birthCal
        comps.timeZone = birthTZ
        comps.year = ymd.year
        comps.month = ymd.month
        comps.day = ymd.day
        comps.hour = tobHour
        comps.minute = tobMinute
        comps.second = tobSecond

        guard let birthLocalInstant = birthCal.date(from: comps) else {
            throw NSError(domain: "BirthTime", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Unable to construct birth datetime from Date of Birth + Time of Birth."
            ])
        }

        return birthLocalInstant
    }
    
    func birthMomentUTCISO8601() throws -> String {
        let utcDate = try birthMomentUTC()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: utcDate)
    }
}

// MARK: - AI Astrology lookups (Solar, Lunar, Chinese)

struct AstrologySignsAIResult: Codable, Equatable {
    let solarSign: String
    let vedicMoonSign: String
    let chineseSign: String
}

extension AppState {
    /// Uses the OpenAI model (via SwiftOpenAI) to infer Solar (Western Sun), Lunar (Moon sign, tropical), and Chinese zodiac.
    /// - Important: This is model-derived. Deterministic Moon-sign requires an ephemeris library/service.
    func lookupAstrologySignsViaSwiftOpenAI() async throws -> AstrologySignsAIResult {
        let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String
        guard let apiKey = key, !apiKey.isEmpty else {
            throw NSError(
                domain: "ExAstra",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "OPENAI_API_KEY missing. Check Secrets.xcconfig + Info.plist"]
            )
        }
        
        let service = OpenAIServiceFactory.service(apiKey: apiKey)
        
        let system = """
        
        You are a precise astrology calculation assistant.
        Task: Determine the user's 
        (1) Western Solar sign (Sun sign), 
        (2) Vedic Moon sign (Rāśi) using:
        - Sidereal zodiac
        - Lahiri (Chitrapaksha) Ayanāṁśa
        - Drik Panchang–style calculations, and 
        (3) Chinese zodiac animal. 
        Rules:
        - Use geocentric planetary positions.
        - Convert local birth time correctly to UTC.
        - Infer timezone from place of birth if not explicitly provided.
        - Use Lahiri Ayanāṁśa only (do not use Raman, KP, or tropical).
        - Determine the Moon’s sidereal longitude and map it to the correct Rāśi.
        - Also determine the Nakshatra and Pada.
        - Do NOT guess. If data is insufficient, state so explicitly.
        - Output MUST be valid JSON only with keys: solarSign, vedicMoonSign, chineseSign.
        - Do not include markdown, backticks, extra keys, or commentary.
        """
        
        let birthUTC = (try? birthMomentUTCISO8601())
        
        let user = """
        Profile:
        \(profileSummary())
        
        Use the birth moment in UTC (do not use the current time): \(birthUTC ?? "Unknown")
        
        Return JSON only.
        """
        
        // MARK: - DEBUG: Print full OpenAI prompt
        print("""
        ================= OPENAI ASTROLOGY QUERY =================
        MODEL: gpt-4o
        
        --- SYSTEM PROMPT ---
        \(system)
        
        --- USER PROMPT ---
        \(user)
        ==========================================================
        """)
        
        let params = ChatCompletionParameters(
            messages: [
                .init(role: .system, content: .text(system)),
                .init(role: .user, content: .text(user))
            ],
            model: .gpt4o,
            temperature: 0.0
        )
        
        let result = try await service.startChat(parameters: params)
        let content = result.choices?.first?.message?.content ?? ""
        
        guard let data = content.data(using: .utf8) else {
            throw NSError(
                domain: "ExAstra",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Model returned non-UTF8 content"]
            )
        }
        
        do {
            return try JSONDecoder().decode(AstrologySignsAIResult.self, from: data)
        } catch {
            if let extracted = Self.extractFirstJSONObject(from: content),
               let extractedData = extracted.data(using: .utf8) {
                return try JSONDecoder().decode(AstrologySignsAIResult.self, from: extractedData)
            }
            
            throw NSError(
                domain: "ExAstra",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse model JSON: \(content)"]
            )
        }
    }
    
    /// Best-effort extraction of the first top-level JSON object from a string.
    private static func extractFirstJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escape = false
        
        for i in text.indices[start..<text.endIndex] {
            let ch = text[i]
            
            if inString {
                if escape {
                    escape = false
                } else if ch == "\\" {
                    escape = true
                } else if ch == "\"" {
                    inString = false
                }
                continue
            }
            
            if ch == "\"" {
                inString = true
                continue
            }
            
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 {
                    return String(text[start...i])
                }
            }
        }
        
        return nil
    }
    
    
    static func ymdFromDateUTC(_ date: Date) -> (y: Int, m: Int, d: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!  // stable reference
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }
    

    static func dateFromYMDUTC(year: Int, month: Int, day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        var comps = DateComponents()
        comps.calendar = cal
        comps.timeZone = cal.timeZone
        comps.year = year
        comps.month = month
        comps.day = day
        
        // Choose noon UTC to avoid any DST/start-of-day edge cases.
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
        
        return cal.date(from: comps) ?? Date(timeIntervalSince1970: 0)
    }
    
    private static func hmsFromDateUTC(_ date: Date) -> (h: Int, m: Int, s: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let c = cal.dateComponents([.hour, .minute, .second], from: date)
        return (c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }

    private static func dateFromHMSUTC(hour: Int, minute: Int, second: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        var comps = DateComponents()
        comps.calendar = cal
        comps.timeZone = cal.timeZone
        comps.year = 2001
        comps.month = 1
        comps.day = 1
        comps.hour = hour
        comps.minute = minute
        comps.second = second

        return cal.date(from: comps) ?? Date(timeIntervalSince1970: 0)
    }
}
