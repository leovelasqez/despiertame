import XCTest
import CoreLocation
@testable import Despiertame

final class AlarmEvaluatorTests: XCTestCase {
    /// Destino de referencia (Bogotá). Los desplazamientos se calculan hacia el norte.
    private let destination = CLLocationCoordinate2D(latitude: 4.6097, longitude: -74.0817)
    /// Metros por grado de latitud a ~4.6° N (esfera WGS84). Error < 0.5 % en distancias cortas.
    private let metersPerDegreeLatitude = 110_574.0

    private func location(
        northMeters: Double,
        accuracy: CLLocationAccuracy = 10,
        speed: CLLocationSpeed = 0,
        age: TimeInterval = 0
    ) -> CLLocation {
        let coordinate = CLLocationCoordinate2D(
            latitude: destination.latitude + northMeters / metersPerDegreeLatitude,
            longitude: destination.longitude
        )
        return CLLocation(
            coordinate: coordinate,
            altitude: 2_600,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 10,
            course: 180,
            speed: speed,
            timestamp: Date().addingTimeInterval(-age)
        )
    }

    private func alarm(
        radius: Double = 500,
        status: AlarmStatus = .armed,
        preAlert: Bool = false,
        preAlertDistance: Double = 2_000,
        preAlertFired: Bool = false
    ) -> Alarm {
        Alarm(
            name: "Terminal",
            coordinate: destination,
            radiusMeters: radius,
            preAlertEnabled: preAlert,
            preAlertDistanceMeters: preAlertDistance,
            status: status,
            preAlertFired: preAlertFired
        )
    }

    // MARK: - Disparo básico

    func testTriggersWhenInsideRadius() {
        let a = alarm(radius: 500)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 300))
        XCTAssertEqual(events.count, 1)
        guard case .trigger(let id, _) = events.first else {
            return XCTFail("Se esperaba un disparo")
        }
        XCTAssertEqual(id, a.id)
    }

    func testDoesNotTriggerWhenFarAway() {
        let a = alarm(radius: 500)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 5_000))
        XCTAssertTrue(events.isEmpty)
    }

    func testInactiveAlarmNeverTriggers() {
        let a = alarm(radius: 500, status: .inactive)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 100))
        XCTAssertTrue(events.isEmpty)
    }

    func testRingingAlarmIsNotTriggeredAgain() {
        let a = alarm(radius: 500, status: .ringing)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 100))
        XCTAssertTrue(events.isEmpty)
    }

    func testMultipleAlarmsAreEvaluatedIndependently() {
        let near = alarm(radius: 500)
        var far = Alarm(
            name: "Otro",
            coordinate: CLLocationCoordinate2D(latitude: destination.latitude + 0.1, longitude: destination.longitude),
            radiusMeters: 500
        )
        far.status = .armed
        let events = AlarmEvaluator.evaluate(alarms: [near, far], location: location(northMeters: 200))
        XCTAssertEqual(events.map { $0.alarmID }, [near.id])
    }

    // MARK: - Precisión y anticipación

    func testAccuracyCreditTriggersSlightlyBeforeRadius() {
        // A 600 m con ±150 m de error: distancia efectiva 450 m ≤ 500 m → suena.
        let a = alarm(radius: 500)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 600, accuracy: 150))
        XCTAssertEqual(events.count, 1)
    }

    func testAccuracyCreditIsCapped() {
        // A 700 m con ±900 m: el crédito se limita a 150 m → efectiva 550 m > 500 m → no suena.
        let a = alarm(radius: 500)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 700, accuracy: 900))
        XCTAssertTrue(events.isEmpty)
    }

    func testSpeedLookaheadAnticipatesTrigger() {
        // A 640 m, 30 m/s (108 km/h): anticipación 150 m, precisión 5 m → 485 m ≤ 500 m → suena.
        let a = alarm(radius: 500)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 640, accuracy: 5, speed: 30))
        XCTAssertEqual(events.count, 1)
    }

    func testSpeedLookaheadIsCapped() {
        // A 800 m a 100 m/s: anticipación limitada a 200 m → 800-5-200 = 595 > 500 → no suena.
        let a = alarm(radius: 500)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 800, accuracy: 5, speed: 100))
        XCTAssertTrue(events.isEmpty)
    }

    func testNegativeSpeedIsTreatedAsZero() {
        let a = alarm(radius: 500)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 560, accuracy: 5, speed: -1))
        XCTAssertTrue(events.isEmpty)
    }

    // MARK: - Lecturas no utilizables

    func testIgnoresVeryImpreciseLocation() {
        let loc = location(northMeters: 100, accuracy: 1_500)
        XCTAssertFalse(AlarmEvaluator.isUsable(loc))
        XCTAssertTrue(AlarmEvaluator.evaluate(alarms: [alarm()], location: loc).isEmpty)
    }

    func testIgnoresInvalidAccuracy() {
        let loc = location(northMeters: 100, accuracy: -1)
        XCTAssertFalse(AlarmEvaluator.isUsable(loc))
    }

    func testIgnoresStaleLocation() {
        let loc = location(northMeters: 100, accuracy: 10, age: 120)
        XCTAssertFalse(AlarmEvaluator.isUsable(loc))
        XCTAssertTrue(AlarmEvaluator.evaluate(alarms: [alarm()], location: loc).isEmpty)
    }

    // MARK: - Pre-aviso

    func testPreAlertFiresWhenApproaching() {
        let a = alarm(radius: 500, preAlert: true, preAlertDistance: 2_000)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 1_500))
        XCTAssertEqual(events.count, 1)
        guard case .preAlert(let id, let distance) = events.first else {
            return XCTFail("Se esperaba un pre-aviso")
        }
        XCTAssertEqual(id, a.id)
        XCTAssertEqual(distance, 1_500, accuracy: 15)
    }

    func testPreAlertDoesNotRepeat() {
        let a = alarm(radius: 500, preAlert: true, preAlertDistance: 2_000, preAlertFired: true)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 1_500))
        XCTAssertTrue(events.isEmpty)
    }

    func testPreAlertDisabledProducesNothing() {
        let a = alarm(radius: 500, preAlert: false)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 1_500))
        XCTAssertTrue(events.isEmpty)
    }

    func testTriggerTakesPrecedenceOverPreAlert() {
        let a = alarm(radius: 500, preAlert: true, preAlertDistance: 2_000)
        let events = AlarmEvaluator.evaluate(alarms: [a], location: location(northMeters: 200))
        XCTAssertEqual(events.count, 1)
        guard case .trigger = events.first else {
            return XCTFail("Dentro del radio debe dispararse la alarma, no el pre-aviso")
        }
    }

    // MARK: - Perfil de precisión

    func testAccuracyProfileThresholds() {
        XCTAssertEqual(AccuracyProfile.forDistance(200), .imminent)
        XCTAssertEqual(AccuracyProfile.forDistance(999), .imminent)
        XCTAssertEqual(AccuracyProfile.forDistance(1_000), .near)
        XCTAssertEqual(AccuracyProfile.forDistance(2_999), .near)
        XCTAssertEqual(AccuracyProfile.forDistance(3_000), .medium)
        XCTAssertEqual(AccuracyProfile.forDistance(9_999), .medium)
        XCTAssertEqual(AccuracyProfile.forDistance(10_000), .far)
        XCTAssertEqual(AccuracyProfile.forDistance(250_000), .far)
    }

    func testRecommendedProfileWithoutLocationIsNear() {
        XCTAssertEqual(AlarmEvaluator.recommendedProfile(alarms: [alarm()], location: nil), .near)
    }

    func testRecommendedProfileUsesNearestArmedAlarm() {
        let near = alarm(radius: 500)
        var far = Alarm(
            name: "Lejos",
            coordinate: CLLocationCoordinate2D(latitude: destination.latitude + 1, longitude: destination.longitude)
        )
        far.status = .armed
        let profile = AlarmEvaluator.recommendedProfile(alarms: [far, near], location: location(northMeters: 1_500))
        XCTAssertEqual(profile, .near)
    }

    func testNearestArmedDistanceIgnoresInactiveAlarms() {
        let inactive = alarm(radius: 500, status: .inactive)
        XCTAssertNil(AlarmEvaluator.nearestArmedDistance(alarms: [inactive], from: location(northMeters: 100)))
    }

    // MARK: - Regiones

    func testRegionIdentifierRoundTrip() {
        let a = alarm()
        XCTAssertEqual(Alarm.alarmID(fromRegionIdentifier: a.regionIdentifier), a.id)
        XCTAssertNil(Alarm.alarmID(fromRegionIdentifier: "otra-cosa"))
    }
}
