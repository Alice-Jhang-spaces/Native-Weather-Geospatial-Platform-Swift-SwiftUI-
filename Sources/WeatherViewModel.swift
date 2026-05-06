import Foundation
import SwiftUI

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [GeoResult] = []
    @Published var selected: GeoResult?
    @Published var weather: WeatherResponse?
    @Published var loading: Bool = false
    @Published var error: String?

    private let service = WeatherService.shared
    private let location = LocationManager()

    func reset() {
        query = ""
        results = []
        selected = nil
        weather = nil
        error = nil
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        loading = true; error = nil; selected = nil; weather = nil
        defer { loading = false }
        do { results = try await service.search(city: trimmed) }
        catch { self.error = error.localizedDescription }
    }

    func pick(_ r: GeoResult) async {
        selected = r; loading = true; error = nil; weather = nil
        defer { loading = false }
        do { weather = try await service.weather(lat: r.latitude, lon: r.longitude) }
        catch { self.error = error.localizedDescription }
    }

    func useCurrentLocation() async {
        loading = true; error = nil; results = []; selected = nil; weather = nil
        defer { loading = false }
        do {
            let place = try await location.resolveCurrentPlace()
            let geo = place.asGeoResult
            selected = geo
            weather = try await service.weather(lat: geo.latitude, lon: geo.longitude)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
