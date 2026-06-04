import CoreLocation

/// Best-effort single device-location fix via CoreLocation. Used only when a
/// DocuPass session sets `gps = true`; the resulting `"lat,lng,accuracy"` is sent
/// as the `Geolocation` header on every subsequent request (the server rejects
/// them otherwise with `LOCATION_HEADER_MISSING`).
///
/// The host app must declare `NSLocationWhenInUseUsageDescription` in its
/// Info.plist, or iOS silently denies the authorization prompt.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// (latitude, longitude, accuracy) or nil if not authorized / no fix.
    func current(timeoutSeconds: Double = 12) async -> (Double, Double, Double)? {
        guard await ensureAuthorized() else { return nil }

        // Fast path: a cached fix.
        if let loc = manager.location {
            return triple(loc)
        }

        // Otherwise request one, bounded by a timeout.
        let loc: CLLocation? = await withCheckedContinuation { cont in
            locContinuation = cont
            manager.requestLocation()
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                guard let self else { return }
                if let pending = self.locContinuation {
                    self.locContinuation = nil
                    pending.resume(returning: nil)
                }
            }
        }
        return loc.map(triple)
    }

    private func ensureAuthorized() async -> Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .notDetermined:
            let status: CLAuthorizationStatus = await withCheckedContinuation { cont in
                authContinuation = cont
                manager.requestWhenInUseAuthorization()
            }
            return status == .authorizedWhenInUse || status == .authorizedAlways
        default: // denied / restricted
            return false
        }
    }

    private func triple(_ loc: CLLocation) -> (Double, Double, Double) {
        (loc.coordinate.latitude, loc.coordinate.longitude, max(loc.horizontalAccuracy, 0))
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            // Only resolve once we leave .notDetermined (the prompt was answered).
            guard status != .notDetermined, let cont = self.authContinuation else { return }
            self.authContinuation = nil
            cont.resume(returning: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in
            if let cont = self.locContinuation {
                self.locContinuation = nil
                cont.resume(returning: last)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let cont = self.locContinuation {
                self.locContinuation = nil
                cont.resume(returning: nil)
            }
        }
    }
}
