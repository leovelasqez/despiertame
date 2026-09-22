import Foundation
import CoreLocation

/// Modo demostración para el simulador y las capturas automáticas de CI.
///
/// Se activa con el argumento de lanzamiento `--demo` y rellena la app con alarmas,
/// favoritos e historial de ejemplo, sin pedir permisos ni arrancar el GPS.
/// Con `--demo-ringing` además deja una alarma sonando para mostrar esa pantalla.
enum DemoMode {
    static let isEnabled = CommandLine.arguments.contains("--demo")
    static let startsRinging = CommandLine.arguments.contains("--demo-ringing")

    /// Posición simulada: en la Autopista Norte de Bogotá, camino a la terminal.
    static let demoLocation = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 4.7300, longitude: -74.0500),
        altitude: 2_600,
        horizontalAccuracy: 12,
        verticalAccuracy: 10,
        course: 200,
        speed: 17,
        timestamp: Date()
    )

    @MainActor
    static func seed(into engine: AlarmEngine) {
        let store = engine.store
        for alarm in store.alarms { store.remove(id: alarm.id) }
        for place in store.favorites { store.removeFavorite(id: place.id) }
        store.clearHistory()

        let terminal = Alarm(
            name: "Terminal Salitre",
            coordinate: CLLocationCoordinate2D(latitude: 4.6560, longitude: -74.1108),
            radiusMeters: 500,
            preAlertEnabled: true,
            preAlertDistanceMeters: 2_000,
            status: startsRinging ? .ringing : .armed,
            triggeredAt: startsRinging ? Date() : nil
        )
        let portal = Alarm(
            name: "Portal Norte",
            coordinate: CLLocationCoordinate2D(latitude: 4.7546, longitude: -74.0459),
            radiusMeters: 300,
            preAlertEnabled: false,
            status: .armed
        )
        let casa = Alarm(
            name: "Casa",
            coordinate: CLLocationCoordinate2D(latitude: 4.6486, longitude: -74.0629),
            radiusMeters: 1_000,
            preAlertEnabled: true,
            preAlertDistanceMeters: 3_000,
            status: .inactive
        )
        store.add(casa)
        store.add(portal)
        store.add(terminal)

        store.addFavorite(SavedPlace(
            name: "Casa",
            subtitle: "Chapinero, Bogotá",
            coordinate: casa.coordinate,
            radiusMeters: 1_000
        ))
        store.addFavorite(SavedPlace(
            name: "Trabajo",
            subtitle: "Calle 26 · Bogotá",
            coordinate: CLLocationCoordinate2D(latitude: 4.6280, longitude: -74.0820),
            radiusMeters: 500
        ))
        store.recordHistory(SavedPlace(
            name: "Terminal Salitre",
            subtitle: "Diagonal 23 · Bogotá",
            coordinate: terminal.coordinate,
            radiusMeters: 500
        ))
        store.recordHistory(SavedPlace(
            name: "Aeropuerto El Dorado",
            subtitle: "Fontibón, Bogotá",
            coordinate: CLLocationCoordinate2D(latitude: 4.7016, longitude: -74.1469),
            radiusMeters: 1_000
        ))

        engine.seedDemoLocation(demoLocation)
    }
}
