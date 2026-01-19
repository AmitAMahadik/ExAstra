ExAstra - Privacy Policy (Draft)

This is a short, plain-language privacy summary you can host on your website and link from App Store Connect. Edit as needed before publishing.

Summary
-------
ExAstra is a personal astrology assistant app. We take user privacy seriously. This policy explains what data the app collects, how it’s used, and how users can contact the developer.

Data collected
--------------
- User-provided profile data: name (optional), date of birth, time of birth, place of birth, and (optionally) geographic coordinates derived from the place of birth. This data is required to generate astrological calculations and summaries.
- Device & usage telemetry: crash reports and basic analytics (only if enabled in the app; currently none are collected by default).

External services
-----------------
- OpenAI: The app sends prompt text containing the user's non-sensitive profile data (name, DOB, time-of-birth, place-of-birth, coordinates when available) to OpenAI to generate astrology summaries. No contact lists, photos, microphone, or other private device data are sent.
- Swiss Ephemeris MCP: To compute deterministic lunar data, the app may send the birth UTC datetime and coordinates to a hosted Swiss Ephemeris MCP service.

How keys are stored and used
---------------------------
- API keys (OpenAI) are not embedded in the distributed app binary. During development, the project uses a local `Secrets.xcconfig` (excluded from source control). For CI builds and App Store submission, use secure secrets in your CI or server-side proxy.

Retention and deletion
----------------------
- Profile data is stored locally in the device's UserDefaults and is not uploaded to the developer's servers except as part of the API requests described above. Users may delete or reset their profile within the app.

Security
--------
- Network calls use HTTPS. Do not store production API keys in source control. Use server-side key management if you need to protect API usage.

Contact
-------
Developer: Amit Mahadik
Email: <your-email@example.com>

Notes for App Review
--------------------
- If you need a test/demo account or a build with stubbed network responses for review, contact the developer at the email above.
