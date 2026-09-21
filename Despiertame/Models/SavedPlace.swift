import Foundation
import CoreLocation

/// Un lugar guardado: favorito o entrada del historial.
struct SavedPlace: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var subtitle: String
    var latitude: Double
    var longitude: Double
    /// Radio con el que se usó por última vez; se reutiliza al crear una alarma desde aquí.
    var radiusMeters: Double
    var lastUsedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String = "",
        coordinate: CLLocationCoordinate2D,
        radiusMeters: Double = AlarmDefaults.radiusMeters,
        lastUsedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.radiusMeters = radiusMeters
        self.lastUsedAt = lastUsedAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Dos lugares se consideran "el mismo sitio" si están a menos de 50 m.
    func isSameSpot(as other: SavedPlace) -> Bool {
        let a = CLLocation(latitude: latitude, longitude: longitude)
        let b = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return a.distance(from: b) < 50
    }
}
