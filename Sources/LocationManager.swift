import Foundation
import CoreLocation

struct ResolvedPlace {
    let latitude: Double
    let longitude: Double
    let name: String
    let admin1: String?
    let country: String?

    var asGeoResult: GeoResult {
        GeoResult(
            id: Int((latitude * 1000).rounded()) ^ Int((longitude * 1000).rounded()),
            name: name,
            country: country,
            admin1: admin1,
            latitude: latitude,
            longitude: longitude
        )
    }
}

enum LocationError: LocalizedError {
    case denied
    case unavailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .denied: return "Location access denied. Enable it in System Settings → Privacy & Security → Location Services."
        case .unavailable: return "Could not determine your location."
        case .timeout: return "Timed out waiting for location."
        }
    }
}

final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func resolveCurrentPlace() async throws -> ResolvedPlace {
        let status = try await withTimeout(seconds: 15) { await self.requestAuthorization() }
        guard status == .authorizedAlways || status == .authorized else {
            throw LocationError.denied
        }
        let location = try await withTimeout(seconds: 15) { try await self.requestOneShotLocation() }
        return try await reverseGeocode(location)
    }

    private func requestAuthorization() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        if current != .notDetermined { return current }
        return await withCheckedContinuation { cont in
            self.authContinuation = cont
            self.manager.requestWhenInUseAuthorization()
        }
    }

    private func requestOneShotLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            self.locationContinuation = cont
            self.manager.requestLocation()
        }
    }

    private func withTimeout<T>(seconds: Double, op: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await op() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw LocationError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func reverseGeocode(_ location: CLLocation) async throws -> ResolvedPlace {
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        let p = placemarks.first
        let name = p?.locality ?? p?.subAdministrativeArea ?? p?.name ?? "Current Location"
        return ResolvedPlace(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            name: name,
            admin1: p?.administrativeArea,
            country: p?.country
        )
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if let cont = authContinuation, manager.authorizationStatus != .notDetermined {
            authContinuation = nil
            cont.resume(returning: manager.authorizationStatus)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, let cont = locationContinuation else { return }
        locationContinuation = nil
        cont.resume(returning: loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let cont = locationContinuation else { return }
        locationContinuation = nil
        cont.resume(throwing: error)
    }
}
