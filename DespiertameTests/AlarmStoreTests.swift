import XCTest
import CoreLocation
@testable import Despiertame

final class AlarmStoreTests: XCTestCase {
    private let coordinate = CLLocationCoordinate2D(latitude: 4.6097, longitude: -74.0817)

    /// Archivo temporal único por prueba, borrado al terminar.
    private func makeFileURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("despiertame-tests-\(UUID().uuidString).json")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    @MainActor
    func testAddUpdateRemove() {
        let store = AlarmStore(fileURL: makeFileURL())
        var alarm = Alarm(name: "Casa", coordinate: coordinate)
        store.add(alarm)
        XCTAssertEqual(store.alarms.count, 1)

        alarm.radiusMeters = 750
        store.update(alarm)
        XCTAssertEqual(store.alarm(id: alarm.id)?.radiusMeters, 750)

        store.remove(id: alarm.id)
        XCTAssertTrue(store.alarms.isEmpty)
    }

    @MainActor
    func testSetStatusResetsPreAlertWhenArming() {
        let store = AlarmStore(fileURL: makeFileURL())
        var alarm = Alarm(name: "Casa", coordinate: coordinate)
        alarm.preAlertFired = true
        store.add(alarm)

        store.setStatus(.armed, for: alarm.id)
        XCTAssertEqual(store.alarm(id: alarm.id)?.status, .armed)
        XCTAssertEqual(store.alarm(id: alarm.id)?.preAlertFired, false)

        store.setStatus(.ringing, for: alarm.id)
        XCTAssertNotNil(store.alarm(id: alarm.id)?.triggeredAt)
        XCTAssertTrue(store.hasRingingAlarms)

        store.setStatus(.inactive, for: alarm.id)
        XCTAssertNil(store.alarm(id: alarm.id)?.triggeredAt)
        XCTAssertFalse(store.hasOnAlarms)
    }

    @MainActor
    func testPersistenceRoundTrip() {
        let fileURL = makeFileURL()
        let store = AlarmStore(fileURL: fileURL)
        let alarm = Alarm(name: "Terminal", coordinate: coordinate, radiusMeters: 300, status: .armed)
        store.add(alarm)
        store.addFavorite(SavedPlace(name: "Trabajo", coordinate: coordinate))
        store.recordHistory(SavedPlace(name: "Terminal", coordinate: coordinate))
        store.saveNow()

        let reloaded = AlarmStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.alarms, [alarm])
        XCTAssertEqual(reloaded.favorites.map { $0.name }, ["Trabajo"])
        XCTAssertEqual(reloaded.history.map { $0.name }, ["Terminal"])
    }

    @MainActor
    func testHistoryDeduplicatesSameSpotAndCapsSize() {
        let store = AlarmStore(fileURL: makeFileURL())
        store.recordHistory(SavedPlace(name: "A", coordinate: coordinate))
        // Mismo sitio (a ~10 m): sustituye, no duplica.
        store.recordHistory(SavedPlace(
            name: "A bis",
            coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude + 0.0001, longitude: coordinate.longitude)
        ))
        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(store.history.first?.name, "A bis")

        for i in 0..<30 {
            store.recordHistory(SavedPlace(
                name: "P\(i)",
                coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude + Double(i + 1) * 0.01, longitude: coordinate.longitude)
            ))
        }
        XCTAssertEqual(store.history.count, AlarmStore.maxHistoryItems)
        XCTAssertEqual(store.history.first?.name, "P29")
    }

    @MainActor
    func testFavoriteReplacesSameSpot() {
        let store = AlarmStore(fileURL: makeFileURL())
        store.addFavorite(SavedPlace(name: "Casa", coordinate: coordinate, radiusMeters: 500))
        store.addFavorite(SavedPlace(name: "Casa nueva", coordinate: coordinate, radiusMeters: 800))
        XCTAssertEqual(store.favorites.count, 1)
        XCTAssertEqual(store.favorites.first?.name, "Casa nueva")
        XCTAssertEqual(store.favorites.first?.radiusMeters, 800)
        XCTAssertNotNil(store.favorite(near: coordinate))
    }

    @MainActor
    func testRenameFavorite() {
        let store = AlarmStore(fileURL: makeFileURL())
        let place = SavedPlace(name: "Casa", coordinate: coordinate)
        store.addFavorite(place)
        store.renameFavorite(id: place.id, name: "Hogar")
        XCTAssertEqual(store.favorites.first?.name, "Hogar")
    }
}
