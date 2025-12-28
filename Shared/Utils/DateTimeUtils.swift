//
//  DateTimeUtils.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/27/25.
//

import Foundation

/// Shared date/time utilities used across the app.
/// Intentionally UI-agnostic.
enum DateTimeUtils {

    /// Combines a date-only and time-only into a single absolute Date (UTC-backed),
    /// interpreting the input using the provided time zone.
    static func makeBirthDateTimeUTC(
        birthDate: Date,
        birthTime: Date,
        timeZone: TimeZone
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let dateParts = calendar.dateComponents([.year, .month, .day], from: birthDate)
        let timeParts = calendar.dateComponents([.hour, .minute, .second], from: birthTime)

        var combined = DateComponents()
        combined.calendar = calendar
        combined.timeZone = timeZone
        combined.year = dateParts.year
        combined.month = dateParts.month
        combined.day = dateParts.day
        combined.hour = timeParts.hour
        combined.minute = timeParts.minute
        combined.second = timeParts.second ?? 0

        return calendar.date(from: combined)
    }
}
