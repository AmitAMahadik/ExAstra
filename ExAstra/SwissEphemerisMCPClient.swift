//
//  SwissEphemerisMCPClient.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/27/25.
//

import Foundation

// MARK: - Zodiac System

public enum ZodiacSystem: String, Sendable, Codable {
    case tropical = "tropical"
    case siderealLahiri = "sidereal_lahiri"
}

// MARK: - Public models

public struct MoonInfo: Sendable, Equatable {
    public let longitude: Double          // absolute ecliptic longitude (0..360)
    public let sign: String               // e.g., "Aquarius"
    public let degreeInSign: Double       // e.g., 6.00
}

// MARK: - Errors

public enum SwissEphemerisMCPError: Error, LocalizedError, Sendable {
    case invalidBaseURL
    case invalidHTTPResponse
    case httpError(status: Int, body: String)
    case missingSessionIdHeader
    case missingSSEDataLine
    case invalidEnvelopeJSON
    case unexpectedEnvelopeShape
    case invalidInnerJSON
    case missingMoonFields
    
    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid base URL."
        case .invalidHTTPResponse:
            return "Invalid HTTP response."
        case .httpError(let status, let body):
            return "HTTP \(status): \(body)"
        case .missingSessionIdHeader:
            return "Missing MCP session id header."
        case .missingSSEDataLine:
            return "Missing SSE data line."
        case .invalidEnvelopeJSON:
            return "Invalid JSON in SSE envelope."
        case .unexpectedEnvelopeShape:
            return "Unexpected MCP envelope shape."
        case .invalidInnerJSON:
            return "Invalid inner JSON payload."
        case .missingMoonFields:
            return "Moon fields not found in tool response."
        }
    }
}

// MARK: - Client

/// A lightweight MCP StreamableHTTP client for swiss-ephemeris-mcp-server.
/// - Works with the Azure Container Apps endpoint you deployed.
/// - Safe to call from any SwiftUI screen (async/await).
public actor SwissEphemerisMCPClient {
    // You can override per-environment (dev/stage/prod)
    public let baseURL: URL
    
    // Cache session ID across calls
    private var sessionId: String?
    
    // Customize timeouts if desired
    private let urlSession: URLSession
    
    // ISO8601 formatter for MCP tool input
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    // MARK: Init
    
    public init(
        baseURL: URL = URL(string: "https://conapp-exastra.yellowrock-7298f3d8.westus.azurecontainerapps.io")!,
        timeoutSeconds: TimeInterval = 30
    ) {
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: Public API
    
    /// Fetch Moon sign + longitude via calculate_planetary_positions.
    /// - Parameters:
    ///   - datetimeUTC: Must be UTC (Date is absolute; you decide how you convert)
    ///   - latitude: decimal degrees
    ///   - longitude: decimal degrees (positive east, negative west)
    public func fetchMoonInfo(
        datetimeUTC: Date,
        latitude: Double,
        longitude: Double,
        zodiac: ZodiacSystem = .siderealLahiri
    ) async throws -> MoonInfo {
        try await ensureInitialized()
        
        let dt = Self.isoFormatter.string(from: datetimeUTC)
        
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": [
                "name": "calculate_planetary_positions",
                "arguments": [
                    "datetime": dt,
                    "latitude": latitude,
                    "longitude": longitude,
                    "zodiac" :zodiac.rawValue
                ]
            ]
        ]
        
        let sseText = try await postMCP(payload: payload, sessionId: sessionId)
        let envelope = try parseFirstSSEDataJSONObject(from: sseText)
        let innerJSONString = try extractInnerTextJSON(fromEnvelope: envelope)
        return try parseMoonInfo(fromInnerJSONString: innerJSONString)
    }
    
    /// Convenience: just the Lunar Sign string (e.g., "Aquarius").
    public func fetchLunarSign(
        datetimeUTC: Date,
        latitude: Double,
        longitude: Double,
        zodiac: ZodiacSystem = .siderealLahiri
    ) async throws -> String {
        try await fetchMoonInfo(
            datetimeUTC: datetimeUTC,
            latitude: latitude,
            longitude: longitude,
            zodiac: zodiac
        ).sign
    }
    
    /// If you ever receive "No valid session ID provided", call this to force re-init next request.
    public func resetSession() {
        self.sessionId = nil
    }
    
    // MARK: - MCP protocol
    
    private func ensureInitialized() async throws {
        if sessionId != nil { return }
        
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [
                "protocolVersion": "2024-11-05",
                "clientInfo": ["name": "ExAstra-iOS", "version": "1.0"],
                "capabilities": [:]
            ]
        ]
        
        let (sseText, headers) = try await postMCPWithHeaders(payload: payload, sessionId: nil)
        
        // Server returns: "mcp-session-id: <id>"
        guard let sid = headers["mcp-session-id"] ?? headers["Mcp-Session-Id".lowercased()] else {
            // Headers are normalized to lowercase in postMCPWithHeaders()
            throw SwissEphemerisMCPError.missingSessionIdHeader
        }
        
        self.sessionId = sid
        
        // Optional: validate initialize response shape (not strictly required)
        _ = sseText
    }
    
    private func postMCP(payload: [String: Any], sessionId: String?) async throws -> String {
        let (text, _) = try await postMCPWithHeaders(payload: payload, sessionId: sessionId)
        return text
    }
    
    private func postMCPWithHeaders(payload: [String: Any], sessionId: String?) async throws -> (String, [String: String]) {
        let url = baseURL.appendingPathComponent("mcp")
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Required by your server (you observed 406 otherwise):
        req.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let sessionId {
            req.setValue(sessionId, forHTTPHeaderField: "Mcp-Session-Id")
        }
        
        req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SwissEphemerisMCPError.invalidHTTPResponse
        }
        
        let bodyText = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            throw SwissEphemerisMCPError.httpError(status: http.statusCode, body: bodyText)
        }
        
        // Normalize headers to lowercase keys
        var headers: [String: String] = [:]
        for (k, v) in http.allHeaderFields {
            if let key = (k as? String)?.lowercased(), let val = v as? String {
                headers[key] = val
            }
        }
        
        return (bodyText, headers)
    }
    
    // MARK: - Parsing (SSE + double JSON)
    
    /// Extract the first JSON object from the first `data: ...` SSE line.
    private func parseFirstSSEDataJSONObject(from sseText: String) throws -> Any {
        // Example:
        // event: message
        // data: {"result": ...}
        // (blank line)
        
        for rawLine in sseText.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("data:") else { continue }
            
            let jsonPart = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            guard let data = jsonPart.data(using: .utf8) else {
                throw SwissEphemerisMCPError.invalidEnvelopeJSON
            }
            
            do {
                return try JSONSerialization.jsonObject(with: data, options: [])
            } catch {
                throw SwissEphemerisMCPError.invalidEnvelopeJSON
            }
        }
        
        throw SwissEphemerisMCPError.missingSSEDataLine
    }
    
    /// Envelope JSON shape:
    /// { "result": { "content": [ { "type":"text", "text":"{...inner json...}" } ] }, "jsonrpc":"2.0", "id": 3 }
    private func extractInnerTextJSON(fromEnvelope envelope: Any) throws -> String {
        guard
            let dict = envelope as? [String: Any],
            let result = dict["result"] as? [String: Any],
            let content = result["content"] as? [[String: Any]],
            let first = content.first,
            let text = first["text"] as? String
        else {
            throw SwissEphemerisMCPError.unexpectedEnvelopeShape
        }
        return text
    }
    
    /// Inner JSON shape:
    /// { "planets": { "Moon": { "longitude": 306.0, "sign": "Aquarius", "degree": 6.0 }, ... }, ... }
    private func parseMoonInfo(fromInnerJSONString inner: String) throws -> MoonInfo {
        guard let data = inner.data(using: .utf8) else {
            throw SwissEphemerisMCPError.invalidInnerJSON
        }
        
        let obj: Any
        do {
            obj = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw SwissEphemerisMCPError.invalidInnerJSON
        }
        
        guard
            let dict = obj as? [String: Any],
            let planets = dict["planets"] as? [String: Any],
            let moon = planets["Moon"] as? [String: Any],
            let lon = moon["longitude"] as? Double,
            let sign = moon["sign"] as? String,
            let degree = moon["degree"] as? Double
        else {
            throw SwissEphemerisMCPError.missingMoonFields
        }
        
        return MoonInfo(longitude: lon, sign: sign, degreeInSign: degree)
    }
}
