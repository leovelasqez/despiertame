import Foundation
import CoreLocation

/// Estado de vida de una alarma.
enum AlarmStatus: String, Codable {
    /// Creada pero apagada. No se vigila.
    case inactive
    /// Encendida: se vigila la ubicación y sonará al entrar en el radio.
    case armed
    /// Sonando ahora mismo, a la espera de que el usuario la detenga.
    case ringing
}

/// Una alarma por distancia: un destino, un radio y opcionalmente un pre-aviso.
struct Alarm: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    /// Radio en metros alrededor del destino dentro del cual suena la alarma.
    var radiusMeters: Double
    var preAlertEnabled: Bool
    /// Distancia en metros a la que se envía el pre-aviso ("te estás acercando").
    var preAlertDistanceMeters: Double
    var status: AlarmStatus
    /// Se marca cuando el pre-aviso ya se envió, para no repetirlo.
    var preAlertFired: Bool
    var createdAt: Date
    /// Momento en que la alarma empezó a sonar (si aplica).
    var triggeredAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        coordinate: CLLocationCoordinate2D,
        radiusMeters: Double = AlarmDefaults.radiusMeters,
        preAlertEnabled: Bool = AlarmDefaults.preAlertEnabled,
        preAlertDistanceMeters: Double = AlarmDefaults.preAlertDistanceMeters,
        status: AlarmStatus = .inactive,
        preAlertFired: Bool = false,
        createdAt: Date = Date(),
        triggeredAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.radiusMeters = radiusMeters
        self.preAlertEnabled = preAlertEnabled
        self.preAlertDistanceMeters = preAlertDistanceMeters
        self.status = status
        self.preAlertFired = preAlertFired
        self.createdAt = createdAt
        self.triggeredAt = triggeredAt
    }

    var coordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var isArmed: Bool { status == .armed }
    var isRinging: Bool { status == .ringing }
    /// Encendida en cualquiera de sus formas (vigilando o sonando).
    var isOn: Bool { status == .armed || status == .ringing }

    /// Distancia en metros desde una ubicación hasta el centro del destino.
    func distance(from location: CLLocation) -> CLLocationDistance {
        self.location.distance(from: location)
    }

    /// Identificador usado para la región de geovallado (geofence) de respaldo.
    var regionIdentifier: String { "alarm-\(id.uuidString)" }

    static func alarmID(fromRegionIdentifier identifier: String) -> UUID? {
        guard identifier.hasPrefix("alarm-") else { return nil }
        return UUID(uuidString: String(identifier.dropFirst("alarm-".count)))
    }
}

/// Valores por defecto y límites de configuración.
enum AlarmDefaults {
    static let radiusMeters: Double = 500
    static let minRadiusMeters: Double = 100
    static let maxRadiusMeters: Double = 5_000
    static let radiusPresets: [Double] = [200, 500, 1_000, 2_000]

    static let preAlertEnabled = true
    static let preAlertDistanceMeters: Double = 2_000
    static let preAlertPresets: [Double] = [1_000, 2_000, 3_000, 5_000]

    /// Máximo de regiones que iOS permite vigilar por app.
    static let maxMonitoredRegions = 20
    /// Tiempo máximo que la alarma suena sola antes de apagarse para no agotar la batería.
    static let maxRingingDuration: TimeInterval = 15 * 60
}
