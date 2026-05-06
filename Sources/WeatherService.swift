import Foundation

struct GeoResult: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let country: String?
    let admin1: String?
    let latitude: Double
    let longitude: Double

    var displayName: String {
        [name, admin1, country].compactMap { $0 }.joined(separator: ", ")
    }
}

struct CurrentWeather: Decodable {
    let temperature: Double
    let windspeed: Double
    let weathercode: Int
    let time: String
}

struct DailyForecast: Decodable {
    let time: [String]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let weathercode: [Int]
}

struct WeatherResponse: Decodable {
    let current_weather: CurrentWeather
    let daily: DailyForecast
}

private struct GeoResponse: Decodable {
    let results: [GeoResult]?
}

enum WeatherError: Error { case badURL }

actor WeatherService {
    static let shared = WeatherService()

    func search(city: String) async throws -> [GeoResult] {
        var comp = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        comp.queryItems = [
            .init(name: "name", value: city),
            .init(name: "count", value: "10"),
            .init(name: "language", value: "en"),
            .init(name: "format", value: "json"),
        ]
        guard let url = comp.url else { throw WeatherError.badURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        return (try JSONDecoder().decode(GeoResponse.self, from: data)).results ?? []
    }

    func weather(lat: Double, lon: Double) async throws -> WeatherResponse {
        var comp = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comp.queryItems = [
            .init(name: "latitude", value: String(lat)),
            .init(name: "longitude", value: String(lon)),
            .init(name: "current_weather", value: "true"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,weathercode"),
            .init(name: "timezone", value: "auto"),
        ]
        guard let url = comp.url else { throw WeatherError.badURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(WeatherResponse.self, from: data)
    }
}

enum WeatherCode {
    static func describe(_ code: Int) -> (symbol: String, label: String) {
        switch code {
        case 0: return ("sun.max.fill", "Clear")
        case 1, 2: return ("cloud.sun.fill", "Partly cloudy")
        case 3: return ("cloud.fill", "Overcast")
        case 45, 48: return ("cloud.fog.fill", "Fog")
        case 51, 53, 55: return ("cloud.drizzle.fill", "Drizzle")
        case 61, 63, 65: return ("cloud.rain.fill", "Rain")
        case 66, 67: return ("cloud.sleet.fill", "Freezing rain")
        case 71, 73, 75, 77: return ("cloud.snow.fill", "Snow")
        case 80, 81, 82: return ("cloud.heavyrain.fill", "Showers")
        case 85, 86: return ("cloud.snow.fill", "Snow showers")
        case 95: return ("cloud.bolt.rain.fill", "Thunderstorm")
        case 96, 99: return ("cloud.bolt.rain.fill", "Thunderstorm w/ hail")
        default: return ("questionmark", "Unknown")
        }
    }
}
