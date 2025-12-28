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

    private var isPlaceValid: Bool {
        validatedMapItem != nil
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
                // NOTE: Keeping your existing behavior. If you later want local-time picking, revisit this.
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
                    let name = validatedMapItem.name ?? state.placeOfBirth
                    let coordinate = validatedMapItem.location.coordinate

                    
                    Text("(\(coordinate.latitude, specifier: "%.2f"), \(coordinate.longitude, specifier: "%.2f")) • Time Zone: \(state.birthTimeZoneIdentifier ?? "Unknown")")
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

            // Single consolidated Signs section:
            // - Moon Sign from Swiss Ephemeris (deterministic)
            // - Solar + Chinese from AI (auto-run on validation)
            Section("Signs") {
                LabeledContent("Moon (Ephemeris)") {
                    Text(state.lunarSignDeterministic.isEmpty ? "—" : state.lunarSignDeterministic)
                }

                if let signsResult {
                    LabeledContent("Solar (Sun)") {
                        Text(signsResult.solarSign)
                    }
                    LabeledContent("Chinese") {
                        Text(signsResult.chineseSign)
                    }
                } else if let signsError, !signsError.isEmpty {
                    Text(signsError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else {
                    Text(isPlaceValid
                         ? "Calculating your Solar and Chinese signs…"
                         : "Validate your place of birth to calculate your signs.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if isLookingUpSigns {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Looking up Solar & Chinese…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let err = state.lunarSignDeterministicError, !err.isEmpty {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                // Optional: keep only a manual moon refresh (useful for debugging / retry)
         /*       Button {
                    Task { await state.refreshDeterministicLunarSign() }
                } label: {
                    HStack(spacing: 10) {
                        if state.isRefreshingLunarSignDeterministic { ProgressView() }
                        Text(state.isRefreshingLunarSignDeterministic
                             ? "Computing Moon sign…"
                             : (isPlaceValid ? "Refresh Moon Sign" : "Validate place of birth to continue"))
                    }
                }
                .disabled(state.isRefreshingLunarSignDeterministic || !isPlaceValid) */
            }

           /* Section {
                Button(role: .destructive) {
                    resetProfile()
                } label: {
                    Text("Reset Profile")
                }
            }*/
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Reset (leading)
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Reset profile")
            }

            // Validate (trailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    validatePlace()
                } label: {
                    Image(systemName: isPlaceValid ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isPlaceValid ? .green : .secondary)
                }
                .disabled(isValidatingPlace)
                .opacity(isValidatingPlace ? 0.5 : 1.0)
                .accessibilityLabel("Validate place of birth")
            }
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
    }

    // MARK: - Actions

    private func invalidateValidatedPlaceAndDerivedResults() {
        // Any edit invalidates the previous validation result and derived calculations.
        validatedMapItem = nil
        placeValidationError = nil

        // Invalidate persisted validated location/timezone.
        state.birthLatitude = nil
        state.birthLongitude = nil
        state.birthTimeZoneIdentifier = nil

        // Clear signs results (prevents stale Solar/Chinese from sticking around).
        signsResult = nil
        signsError = nil
        isLookingUpSigns = false

        // Clear deterministic lunar display (optional; keeps UI consistent).
        state.lunarSignDeterministic = ""
        state.moonLongitudeDeterministic = nil
        state.lunarSignDeterministicError = nil
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

                        // Persist validated coordinates/timezone for downstream UTC conversion.
                        let coord = first.location.coordinate
                        state.birthLatitude = coord.latitude
                        state.birthLongitude = coord.longitude
                        state.birthTimeZoneIdentifier = first.timeZone?.identifier

                        // Keep the free-text place in sync with what was validated.
                        state.placeOfBirth = query

                        // Kick off deterministic lunar sign calc (Swiss Ephemeris MCP)
                        Task { await state.refreshDeterministicLunarSign() }

                        // Kick off Solar + Chinese lookup automatically (AI)
                        startSolarAndChineseLookup()

                        // Debug
                        print("[PlaceValidation] query=\(query)")
                        print("[PlaceValidation] lat=\(coord.latitude), lon=\(coord.longitude)")
                        print("[PlaceValidation] tz=\(first.timeZone?.identifier ?? "nil")")
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
        // Reset persisted profile state
        state.resetProfile()

        // Reset view-local UI state
        isLookingUpSigns = false
        signsResult = nil
        signsError = nil
        isValidatingPlace = false
        validatedMapItem = nil
        placeValidationError = nil
    }

    private func startSolarAndChineseLookup() {
        guard isPlaceValid else { return }

        isLookingUpSigns = true
        signsError = nil
        signsResult = nil

        Task {
            do {
                let result = try await state.lookupAstrologySignsViaSwiftOpenAI()
                await MainActor.run {
                    signsResult = result
                    isLookingUpSigns = false
                }
            } catch {
                await MainActor.run {
                    signsError = error.localizedDescription
                    isLookingUpSigns = false
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("ProfileView") {
    NavigationStack {
        ProfileView()
            .environmentObject(ProfileView_Previews.makePreviewState())
    }
}

private enum ProfileView_Previews {
    static func makePreviewState() -> AppState {
        let s = AppState()

        // Populate with realistic sample values
        s.name = "Rahul Mahadik"
        s.gender = .male

        // DOB: Jan 15, 2005 (use your UTC-stable helper)
        s.dob = AppState.dateFromYMDUTC(year: 2005, month: 1, day: 15)

        // TOB: 03:42:00
        s.tobHour = 3
        s.tobMinute = 42
        s.tobSecond = 0

        s.placeOfBirth = "Mountain View, CA"
        s.birthTimeZoneIdentifier = "America/Los_Angeles"
        s.birthLatitude = 37.39261
        s.birthLongitude = -122.07978

        // Make the signs section look “filled” in preview
        s.lunarSignDeterministic = "Pisces (Meena)"
        s.moonLongitudeDeterministic = 339.6269
        s.lunarSignDeterministicError = nil
        s.isRefreshingLunarSignDeterministic = false

        return s
    }
}

