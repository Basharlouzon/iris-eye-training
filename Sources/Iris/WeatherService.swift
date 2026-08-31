import Foundation
import SwiftUI

/// All outbound requests must be https, hit only allow-listed hosts, and never
/// target loopback/private/reserved addresses.
enum NetworkGuard {
    static let allowedHosts: Set<String> = [
        "api.open-meteo.com",
        "geocoding-api.open-meteo.com",
    ]

    static func validatedURL(_ string: String) -> URL? {
        guard let url = URL(string: string), let host = url.host?.lowercased() else { return nil }
        guard url.scheme == "https" else { return nil }

        let blocked = ["localhost", "127.0.0.1", "0.0.0.0", "::1", "169.254.169.254"]
        if blocked.contains(host) { return nil }
        if host.hasSuffix(".local") || host.hasPrefix("10.") || host.hasPrefix("192.168.") { return nil }
        if host.range(of: #"^172\.(1[6-9]|2\d|3[01])\."#, options: .regularExpression) != nil { return nil }

        guard allowedHosts.contains(host) else { return nil }
        return url
    }
}

@MainActor
final class WeatherService: ObservableObject {
    @Published var tempC: Double?
    @Published var weatherCode = 0
    @Published var highC: Double?
    @Published var lowC: Double?
    @Published var status: Status = .idle

    enum Status: Equatable { case idle, loading, loaded, failed }

    var city: String {
        UserDefaults.standard.string(forKey: SettingsKeys.city) ?? "New York"
    }

    struct Cache: Codable {
        let temp: Double
        let code: Int
        let high: Double?
        let low: Double?
    }

    private struct Forecast: Codable {
        let current: Current?
        let daily: Daily?
        struct Current: Codable { let temperature_2m: Double; let weather_code: Int }
        struct Daily: Codable { let temperature_2m_max: [Double]; let temperature_2m_min: [Double] }
    }

    private struct GeoResult: Codable {
        let results: [Geo]?
        struct Geo: Codable { let name: String; let latitude: Double; let longitude: Double }
    }

    private var geoCache: GeoResult.Geo?
    private var lastRefresh: Date?
    private var refreshTimer: Timer?

    func setCity(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: SettingsKeys.city)
        geoCache = nil
        objectWillChange.send()
        refreshIfNeeded(force: true)
    }

    func refreshIfNeeded(force: Bool = false) {
        if force || lastRefresh == nil || Date().timeIntervalSince(lastRefresh!) > 1800 {
            Task { await refresh() }
        }
        if refreshTimer == nil {
            let t = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshIfNeeded(force: true) }
            }
            t.tolerance = 30
            refreshTimer = t
        }
    }

    func refresh() async {
        status = .loading
        do {
            let coords = try await geocode(city)
            var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
            comps.queryItems = [
                .init(name: "latitude", value: String(format: "%.4f", coords.latitude)),
                .init(name: "longitude", value: String(format: "%.4f", coords.longitude)),
                .init(name: "current", value: "temperature_2m,weather_code"),
                .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
                .init(name: "forecast_days", value: "1"),
                .init(name: "timezone", value: "auto"),
            ]
            guard let url = NetworkGuard.validatedURL(comps.string ?? "") else {
                throw URLError(.badURL)
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(Forecast.self, from: data)
            tempC = decoded.current?.temperature_2m
            weatherCode = decoded.current?.weather_code ?? 0
            highC = decoded.daily?.temperature_2m_max.first
            lowC = decoded.daily?.temperature_2m_min.first
            lastRefresh = Date()
            status = .loaded
            if let t = tempC,
               let payload = try? JSONEncoder().encode(Cache(temp: t, code: weatherCode, high: highC, low: lowC)) {
                UserDefaults.standard.set(payload, forKey: "weather.cache")
            }
        } catch {
            if let raw = UserDefaults.standard.data(forKey: "weather.cache"),
               let cached = try? JSONDecoder().decode(Cache.self, from: raw) {
                tempC = cached.temp
                weatherCode = cached.code
                highC = cached.high
                lowC = cached.low
                status = .loaded
            } else {
                status = .failed
            }
        }
    }

    private func geocode(_ name: String) async throws -> GeoResult.Geo {
        if let geoCache { return geoCache }
        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        comps.queryItems = [
            .init(name: "name", value: name),
            .init(name: "count", value: "1"),
        ]
        guard let url = NetworkGuard.validatedURL(comps.string ?? "") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(GeoResult.self, from: data)
        guard let geo = decoded.results?.first else {
            throw URLError(.cannotFindHost)
        }
        geoCache = geo
        return geo
    }

    static func describe(_ code: Int) -> (label: String, symbol: String) {
        switch code {
        case 0: return ("Clear", "sun.max.fill")
        case 1, 2: return ("Partly Cloudy", "cloud.sun.fill")
        case 3: return ("Cloudy", "cloud.fill")
        case 45, 48: return ("Foggy", "cloud.fog.fill")
        case 51...57: return ("Drizzle", "cloud.drizzle.fill")
        case 61...67: return ("Rain", "cloud.rain.fill")
        case 71...77: return ("Snow", "cloud.snow.fill")
        case 80...82: return ("Showers", "cloud.heavyrain.fill")
        case 95...99: return ("Storm", "cloud.bolt.rain.fill")
        default: return ("—", "cloud.fill")
        }
    }
}
