//
//  ProfileView.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//

import SwiftUI
import MapKit

struct ProfileView: View {
    @EnvironmentObject private var state: AppState

    @State private var isLookingUpSigns: Bool = false
    @State private var signsResult: AstrologySignsAIResult? = nil
    @State private var signsError: String? = nil

    @State private var isValidatingPlace: Bool = false
    @State private var validatedMapItem: MKMapItem? = nil
    @State private var placeValidationError: String? = nil

    @State private var showResetConfirm = false

    // Unified (in-unison) display values for the three signs
    @State private var displayedMoonSign: String = "—"
    @State private var displayedSunSign: String = "—"
    @State private var displayedChineseSign: String = "—"
    @State private var unifiedSignsError: String? = nil

    private var isPlaceValid: Bool {
        validatedMapItem != nil
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $state.name)
                    .textContentType(.name)

                Picker("Gender", selection: $state.gender) {
                    ForEach(Gender.allCases) { g in
                        Text(g.rawValue).tag(g)
                    }
                }

                DatePicker("Date of Birth", selection: $state.dob, displayedComponents: .date)
                    .onChange(of: state.dob) { _, _ in
                        invalidateValidatedPlaceAndDerivedResults()
                    }

                DatePicker(
                    "Time of Birth",
                    selection: Binding(
                        get: { state.timeOfBirthPickerDate },
                        set: { state.timeOfBirthPickerDate = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                .onChange(of: state.timeOfBirthPickerDate) { _, _ in
                    invalidateValidatedPlaceAndDerivedResults()
                }

                HStack(alignment: .center, spacing: 10) {
                    TextField("Place of Birth (City, Country)", text: $state.placeOfBirth)
                        .textContentType(.addressCity)
                        .onChange(of: state.placeOfBirth) { _, _ in
                            invalidateValidatedPlaceAndDerivedResults()
                        }

                    if isValidatingPlace {
                        ProgressView()
                    } else if isPlaceValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("Place of birth validated")
                    }

                    Button("Validate") {
                        validatePlace()
                    }
                    .disabled(isValidatingPlace)
                }

                if let validatedMapItem {
                    let coordinate = validatedMapItem.location.coordinate

                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .symbolRenderingMode(.hierarchical)

                        Text(formatLatLonDM(latitude: coordinate.latitude, longitude: coordinate.longitude))

                        Image(systemName: "clock")
                            .symbolRenderingMode(.hierarchical)

                        Text(state.birthTimeZoneIdentifier ?? "Unknown")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else if let placeValidationError, !placeValidationError.isEmpty {
                    Text(placeValidationError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else {
                    Text("Tip: Use ‘City, State/Region, Country’ for best results.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Signs") {
                LabeledContent {
                    Text(displayedMoonSign)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                } label: {
                    Label("Lunar (Ephemeris)", systemImage: "moon.stars.fill")
                        .symbolRenderingMode(.hierarchical)
                }

                LabeledContent {
                    Text(displayedSunSign)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                } label: {
                    Label("Sun Sign", systemImage: "sun.max.fill")
                        .symbolRenderingMode(.hierarchical)
                }

                LabeledContent {
                    Text(displayedChineseSign)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                } label: {
                    Label("Chinese Zodiac", systemImage: "sparkles")
                        .symbolRenderingMode(.hierarchical)
                }

                if isLookingUpSigns {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Calculating signs…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if !isPlaceValid {
                    Text("Validate your place of birth to calculate your signs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let unifiedSignsError, !unifiedSignsError.isEmpty {
                    Text(unifiedSignsError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

        }
        .scrollDisabled(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Text("Reset Profile")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .buttonStyle(.plain)
        }
        .confirmationDialog(
            "Reset Profile?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset Profile", role: .destructive) {
                resetProfile()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will clear your saved profile details and validated location.")
        }
        .onAppear {
            if displayedMoonSign == "—" {
                let existingMoon = state.lunarSignDeterministic
                if !existingMoon.isEmpty, existingMoon != "—" { displayedMoonSign = existingMoon }
            }
            if displayedSunSign == "—", let signsResult {
                displayedSunSign = signsResult.solarSign
                displayedChineseSign = signsResult.chineseSign
            }
        }
    }

    // MARK: - Helpers

    private func formatCoordinateDM(_ value: Double, positive: String, negative: String) -> String {
        let absValue = abs(value)
        let degrees = Int(absValue)
        let minutes = Int((absValue - Double(degrees)) * 60.0)
        let direction = value >= 0 ? positive : negative
        return "\(degrees)° \(minutes)′ \(direction)"
    }

    private func formatLatLonDM(latitude: Double, longitude: Double) -> String {
        let lat = formatCoordinateDM(latitude, positive: "N", negative: "S")
        let lon = formatCoordinateDM(longitude, positive: "E", negative: "W")
        return "\(lat), \(lon)"
    }

    private func invalidateValidatedPlaceAndDerivedResults() {
        validatedMapItem = nil
        placeValidationError = nil

        state.birthLatitude = nil
        state.birthLongitude = nil
        state.birthTimeZoneIdentifier = nil

        signsResult = nil
        signsError = nil
        isLookingUpSigns = false

        state.lunarSignDeterministic = ""
        state.moonLongitudeDeterministic = nil
        state.lunarSignDeterministicError = nil

        displayedMoonSign = "—"
        displayedSunSign = "—"
        displayedChineseSign = "—"
        unifiedSignsError = nil
    }

    private func validatePlace() {
        isValidatingPlace = true
        placeValidationError = nil
        validatedMapItem = nil

        let query = state.placeOfBirth.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                guard !query.isEmpty else {
                    throw NSError(
                        domain: "PlaceValidation",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Please enter a city and country (e.g., Pune, India)."]
                    )
                }

                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query

                let search = MKLocalSearch(request: request)
                let response = try await search.start()

                await MainActor.run {
                    if let first = response.mapItems.first {
                        validatedMapItem = first
                        isValidatingPlace = false

                        let coord = first.location.coordinate
                        state.birthLatitude = coord.latitude
                        state.birthLongitude = coord.longitude
                        state.birthTimeZoneIdentifier = first.timeZone?.identifier

                        let city = first.name?.trimmingCharacters(in: .whitespacesAndNewlines)

                        // iOS 26 deprecates `placemark`; prefer `address` / `addressRepresentations`.
                        let country: String? = {
                            if #available(iOS 26.0, *) {
                                // Best-effort: derive country/region from the full address string.
                                // (MapKit no longer provides structured country fields on MKMapItem.)
                                let full = first.address?.fullAddress
                                let last = full?.split(separator: ",").last.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                                return (last?.isEmpty == false) ? last : nil
                            } else {
                                return first.placemark.country?.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }()

                        if let city, !city.isEmpty, let country, !country.isEmpty {
                            state.placeOfBirth = "\(city), \(country)"
                        } else if let city, !city.isEmpty {
                            state.placeOfBirth = city
                        } else {
                            state.placeOfBirth = query
                        }

                        startUnifiedSignsLookup()
                    } else {
                        placeValidationError = "No matching location found. Try a more specific format like ‘City, State/Region, Country’."
                        isValidatingPlace = false
                    }
                }
            } catch {
                await MainActor.run {
                    placeValidationError = error.localizedDescription
                    isValidatingPlace = false
                }
            }
        }
    }

    private func resetProfile() {
        state.resetProfile()

        isLookingUpSigns = false
        signsResult = nil
        signsError = nil
        isValidatingPlace = false
        validatedMapItem = nil
        placeValidationError = nil

        displayedMoonSign = "—"
        displayedSunSign = "—"
        displayedChineseSign = "—"
        unifiedSignsError = nil
    }

    private func startUnifiedSignsLookup() {
        guard isPlaceValid else { return }

        isLookingUpSigns = true
        signsError = nil
        signsResult = nil
        unifiedSignsError = nil

        displayedMoonSign = "—"
        displayedSunSign = "—"
        displayedChineseSign = "—"

        Task {
            do {
                async let moonInfo = state.computeDeterministicMoonInfo()
                async let ai = state.lookupAstrologySignsViaSwiftOpenAI()

                let (moon, aiResult) = try await (moonInfo, ai)

                await MainActor.run {
                    displayedMoonSign = moon.sign
                    displayedSunSign = aiResult.solarSign
                    displayedChineseSign = aiResult.chineseSign

                    signsResult = aiResult
                    state.lunarSignDeterministic = moon.sign
                    state.moonLongitudeDeterministic = moon.longitude

                    isLookingUpSigns = false
                }
            } catch {
                await MainActor.run {
                    unifiedSignsError = error.localizedDescription
                    isLookingUpSigns = false
                }
            }
        }
    }
}

#Preview("ProfileView") {
    NavigationStack {
        ProfileView()
            .environmentObject(ProfileView_Previews.makePreviewState())
    }
}

private enum ProfileView_Previews {
    static func makePreviewState() -> AppState {
        let s = AppState()
        s.name = "Rahul Mahadik"
        s.gender = .male
        s.dob = AppState.dateFromYMDUTC(year: 2005, month: 1, day: 15)
        s.tobHour = 3
        s.tobMinute = 42
        s.tobSecond = 0
        s.placeOfBirth = "Mountain View, CA"
        s.birthTimeZoneIdentifier = "America/Los_Angeles"
        s.birthLatitude = 37.39261
        s.birthLongitude = -122.07978
        s.lunarSignDeterministic = "Pisces (Meena)"
        s.moonLongitudeDeterministic = 339.6269
        return s
    }
}
