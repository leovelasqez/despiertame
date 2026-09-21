import Foundation
import CoreLocation

/// Evento producido al evaluar las alarmas frente a una nueva ubicación.
enum AlarmEvent: Equatable {
    /// El usuario se está acercando: enviar el pre-aviso.
    case preAlert(alarmID: UUID, distance: CLLocationDistance)
    /// El usuario entró en el radio: hacer sonar la alarma.
    case trigger(alarmID: UUID, distance: CLLocationDistance)

    var alarmID: UUID {
        switch self {
        case .preAlert(let id, _), .trigger(let id, _):
            return id
        }
    }
}

/// Perfil de precisión GPS según la distancia al destino armado más cercano.
/// Lejos del destino se ahorra batería; cerca se usa la máxima precisión.
enum AccuracyProfile: Equatable, CaseIterable {
    case far
    case medium
    case near
    case imminent

    var desiredAccuracy: CLLocationAccuracy {
        switch self {
        case .far: return kCLLocationAccuracyKilometer
        case .medium: return kCLLocationAccuracyHundredMeters
        case .near: return kCLLocationAccuracyNearestTenMeters
        case .imminent: return kCLLocationAccuracyBest
        }
    }

    var distanceFilter: CLLocationDistance {
        switch self {
        case .far: return 500
        case .medium: return 100
        case .near: return 25
        case .imminent: return kCLDistanceFilterNone
        }
    }

    /// Descripción corta para mostrar en la interfaz.
    var label: String {
        switch self {
        case .far: return "Ahorro de batería"
        case .medium: return "Precisión media"
        case .near: return "Precisión alta"
        case .imminent: return "Precisión máxima"
        }
    }

    static func forDistance(_ distance: CLLocationDistance) -> AccuracyProfile {
        switch distance {
        case ..<1_000: return .imminent
        case ..<3_000: return .near
        case ..<10_000: return .medium
        default: return .far
        }
    }
}

/// Lógica pura, sin efectos secundarios, que decide cuándo suena una alarma.
/// Se mantiene separada del motor para poder probarla con pruebas unitarias.
enum AlarmEvaluator {
    /// Lecturas con peor precisión horizontal que esto no sirven para disparar la alarma.
    static let maxUsableAccuracy: CLLocationAccuracy = 1_000
    /// Tope a la "ventaja" que se concede por imprecisión GPS al calcular la distancia efectiva.
    static let maxAccuracyCredit: CLLocationDistance = 150
    /// Segundos de anticipación por velocidad: a 90 km/h son ~125 m.
    static let lookaheadSeconds: TimeInterval = 5
    static let maxLookahead: CLLocationDistance = 200
    /// Antigüedad máxima de una lectura para tenerla en cuenta.
    static let maxLocationAge: TimeInterval = 60

    /// Una lectura es utilizable si es reciente y su precisión es razonable.
    static func isUsable(_ location: CLLocation, now: Date = Date()) -> Bool {
        guard location.horizontalAccuracy >= 0 else { return false }
        guard location.horizontalAccuracy <= maxUsableAccuracy else { return false }
        let age = now.timeIntervalSince(location.timestamp)
        return age <= maxLocationAge
    }

    /// Distancia "efectiva" al destino: la distancia medida menos la imprecisión GPS
    /// (acotada) y menos la anticipación por velocidad. Es deliberadamente optimista:
    /// es preferible despertar unos metros antes que pasarse la parada.
    static func effectiveDistance(from location: CLLocation, to alarm: Alarm) -> CLLocationDistance {
        let raw = alarm.distance(from: location)
        let accuracyCredit = max(0, min(location.horizontalAccuracy, maxAccuracyCredit))
        let speed = max(0, location.speed) // speed < 0 significa "desconocida"
        let lookahead = min(speed * lookaheadSeconds, maxLookahead)
        return raw - accuracyCredit - lookahead
    }

    /// Evalúa todas las alarmas armadas frente a una ubicación.
    static func evaluate(alarms: [Alarm], location: CLLocation, now: Date = Date()) -> [AlarmEvent] {
        guard isUsable(location, now: now) else { return [] }
        var events: [AlarmEvent] = []
        for alarm in alarms where alarm.isArmed {
            let raw = alarm.distance(from: location)
            let effective = effectiveDistance(from: location, to: alarm)
            if effective <= alarm.radiusMeters {
                events.append(.trigger(alarmID: alarm.id, distance: raw))
            } else if alarm.preAlertEnabled, !alarm.preAlertFired, raw <= alarm.preAlertDistanceMeters {
                events.append(.preAlert(alarmID: alarm.id, distance: raw))
            }
        }
        return events
    }

    /// Distancia (en metros) al destino armado más cercano, o nil si no hay alarmas armadas.
    static func nearestArmedDistance(alarms: [Alarm], from location: CLLocation) -> CLLocationDistance? {
        alarms
            .filter { $0.isArmed }
            .map { $0.distance(from: location) }
            .min()
    }

    /// Perfil de precisión recomendado para el conjunto de alarmas y la ubicación actual.
    static func recommendedProfile(alarms: [Alarm], location: CLLocation?) -> AccuracyProfile {
        guard let location, let nearest = nearestArmedDistance(alarms: alarms, from: location) else {
            // Sin ubicación conocida aún: precisión alta hasta saber dónde estamos.
            return .near
        }
        return AccuracyProfile.forDistance(nearest)
    }
}
