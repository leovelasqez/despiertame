import Foundation
import CoreLocation
import Observation

/// Envoltorio de CLLocationManager con:
/// - actualizaciones continuas en segundo plano (modo `location` en UIBackgroundModes),
/// - precisión adaptativa según la distancia al destino (ahorro de batería),
/// - regiones circulares (geofence) como respaldo, capaces de relanzar la app si iOS la cierra.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var accuracyAuthorization: CLAccuracyAuthorization
    private(set) var lastLocation: CLLocation?
    private(set) var lastFixDate: Date?
    private(set) var lastErrorMessage: String?
    private(set) var isUpdating = false
    private(set) var isBackgroundEnabled = false
    private(set) var currentProfile: AccuracyProfile = .near

    /// Nueva ubicación utilizable (ya filtrada por edad y precisión básica).
    var onLocation: ((CLLocation) -> Void)?
    /// Entrada en una región de geovallado; entrega el identificador de la región.
    var onRegionEntered: ((String) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
        super.init()
        manager.delegate = self
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.desiredAccuracy = currentProfile.desiredAccuracy
        manager.distanceFilter = currentProfile.distanceFilter
    }

    // MARK: - Permisos

    var hasWhenInUse: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var hasAlways: Bool { authorizationStatus == .authorizedAlways }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var isNotDetermined: Bool { authorizationStatus == .notDetermined }

    var hasPreciseLocation: Bool { accuracyAuthorization == .fullAccuracy }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func requestTemporaryFullAccuracy() {
        guard !hasPreciseLocation else { return }
        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "PrecisionRequired")
    }

    // MARK: - Actualizaciones

    /// Empieza a recibir ubicaciones. Con `background: true` la app sigue recibiéndolas
    /// con la pantalla bloqueada o en segundo plano (requiere permiso "Mientras se usa" o "Siempre").
    func startUpdating(profile: AccuracyProfile, background: Bool) {
        apply(profile: profile)
        if background != isBackgroundEnabled {
            manager.allowsBackgroundLocationUpdates = background
            isBackgroundEnabled = background
        }
        if !isUpdating {
            manager.startUpdatingLocation()
            isUpdating = true
        }
    }

    func stopUpdating() {
        guard isUpdating else { return }
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        isBackgroundEnabled = false
        isUpdating = false
    }

    func apply(profile: AccuracyProfile) {
        guard profile != currentProfile else { return }
        currentProfile = profile
        manager.desiredAccuracy = profile.desiredAccuracy
        manager.distanceFilter = profile.distanceFilter
    }

    // MARK: - Regiones de respaldo

    static var isRegionMonitoringAvailable: Bool {
        CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
    }

    /// Sincroniza las regiones vigiladas con las alarmas armadas (máx. 20 en iOS).
    func syncMonitoredRegions(for alarms: [Alarm]) {
        guard LocationService.isRegionMonitoringAvailable else { return }
        let wanted = alarms
            .filter { $0.isArmed }
            .prefix(AlarmDefaults.maxMonitoredRegions)
        let wantedIDs = Set(wanted.map { $0.regionIdentifier })

        for region in manager.monitoredRegions where !wantedIDs.contains(region.identifier) {
            manager.stopMonitoring(for: region)
        }
        let existingIDs = Set(manager.monitoredRegions.map { $0.identifier })
        for alarm in wanted where !existingIDs.contains(alarm.regionIdentifier) {
            let radius = min(max(alarm.radiusMeters, 100), manager.maximumRegionMonitoringDistance)
            let region = CLCircularRegion(center: alarm.coordinate, radius: radius, identifier: alarm.regionIdentifier)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
    }

    func stopMonitoringAllRegions() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
    }

    // MARK: - CLLocationManagerDelegate (llega en el hilo principal; saltamos al actor)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let accuracy = manager.accuracyAuthorization
        Task { @MainActor in
            self.authorizationStatus = status
            self.accuracyAuthorization = accuracy
            self.onAuthorizationChange?(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.lastErrorMessage = nil
            self.lastLocation = latest
            self.lastFixDate = Date()
            self.onLocation?(latest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        // kCLErrorLocationUnknown (0) es transitorio: el GPS sigue intentándolo.
        if nsError.domain == kCLErrorDomain, nsError.code == CLError.locationUnknown.rawValue {
            return
        }
        let message = error.localizedDescription
        Task { @MainActor in
            self.lastErrorMessage = message
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let identifier = region.identifier
        Task { @MainActor in
            self.onRegionEntered?(identifier)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        let message = "No se pudo vigilar la región de respaldo: \(error.localizedDescription)"
        Task { @MainActor in
            self.lastErrorMessage = message
        }
    }
}
