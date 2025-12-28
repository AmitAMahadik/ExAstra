//
//  ProfileView.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//

// ProfileView.swift
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

    private var isPlaceValid: Bool {
        // Consider the place valid only if we have a geocoded result for the current input.
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
                DatePicker("Time of Birth", selection: Binding(
                    get: { state.timeOfBirthPickerDate },
                    set: { state.timeOfBirthPickerDate = $0 }
                ), displayedComponents: .hourAndMinute)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                
                HStack(alignment: .center, spacing: 10) {
                    TextField("Place of Birth (City, Country)", text: $state.placeOfBirth)
                        .textContentType(.addressCity)
                        .onChange(of: state.placeOfBirth) { _, _ in
                            // Any edit invalidates the previous search result.
                            validatedMapItem = nil
                            placeValidationError = nil

                            // Also invalidate persisted validated location/timezone.
                            state.birthLatitude = nil
                            state.birthLongitude = nil
                            state.birthTimeZoneIdentifier = nil
                        }

                    if isValidatingPlace {
                        ProgressView()
                    } else if isPlaceValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("Place of birth validated")
                    }

                    Button("Validate") {
                        isValidatingPlace = true
                        placeValidationError = nil
                        validatedMapItem = nil

                        let query = state.placeOfBirth.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            do {
                                guard !query.isEmpty else {
                                    throw NSError(domain: "PlaceValidation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please enter a city and country (e.g., Pune, India)."])
                                }

                                let request = MKLocalSearch.Request()
                                request.naturalLanguageQuery = query
                                // Optional: you can also set a broad region hint if you want to bias results.

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

                                        // NEW: Kick off deterministic lunar sign calc (Swiss Ephemeris MCP)
                                        Task { await state.refreshDeterministicLunarSign() }
                                        

                                        // Keep the free-text place in sync with what was validated.
                                        // (This ensures profileSummary() uses the same string the user validated.)
                                        state.placeOfBirth = query

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
                    .disabled(isValidatingPlace)
                }

                if let validatedMapItem {
                    let name = validatedMapItem.name ?? state.placeOfBirth
                    let coordinate = validatedMapItem.location.coordinate
                    Text("Validated: \(name) (\(coordinate.latitude, specifier: "%.5f"), \(coordinate.longitude, specifier: "%.5f"))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Timezone: \(state.birthTimeZoneIdentifier ?? "Unknown")")
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
                Button {
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
                } label: {
                    HStack(spacing: 10) {
                        if isLookingUpSigns {
                            ProgressView()
                        }
                        Text(isLookingUpSigns ? "Looking up signs…" : (isPlaceValid ? "Lookup Solar, Lunar & Chinese Signs" : "Validate place of birth to continue"))
                    }
                }
                .disabled(isLookingUpSigns || !isPlaceValid)

                if let signsResult {
                    LabeledContent("Solar (Sun)") {
                        Text(signsResult.solarSign)
                    }
                    LabeledContent("Lunar (Moon)") {
                        Text(signsResult.vedicMoonSign)
                    }
                    LabeledContent("Chinese") {
                        Text(signsResult.chineseSign)
                    }
                } else if let signsError, !signsError.isEmpty {
                    Text(signsError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else {
                    Text(isPlaceValid ? "Tap the button to calculate your signs from your profile." : "First validate your place of birth so we can reliably calculate signs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Lunar Sign (Ephemeris)") {
                HStack {
                    Text("Moon sign")
                    Spacer()
                    Text(state.lunarSignDeterministic)
                }

                if let lon = state.moonLongitudeDeterministic {
                    HStack {
                        Text("Moon longitude")
                        Spacer()
                        Text(String(format: "%.6f°", lon))
                    }
                }

                if let err = state.lunarSignDeterministicError, !err.isEmpty {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else {
                    Text(isPlaceValid
                         ? "Deterministic result from Swiss Ephemeris (requires validated place/timezone)."
                         : "Validate your place of birth to compute deterministic Lunar Sign.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Button {
                    Task { await state.refreshDeterministicLunarSign() }
                } label: {
                    HStack(spacing: 10) {
                        if state.isRefreshingLunarSignDeterministic { ProgressView() }
                        Text(state.isRefreshingLunarSignDeterministic
                             ? "Computing…"
                             : (isPlaceValid ? "Compute Lunar Sign" : "Validate place of birth to continue"))
                    }
                }
                .disabled(state.isRefreshingLunarSignDeterministic || !isPlaceValid)
            }

            Section {
                Button(role: .destructive) {
                    state.resetProfile()
                } label: {
                    Text("Reset Profile")
                }
            }
        }
        .navigationTitle("Profile")
    }
}
