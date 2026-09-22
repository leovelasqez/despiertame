import Foundation
import CoreLocation
import Observation

/// Motor central: recibe ubicaciones, evalúa las alarmas, dispara el sonido y las
/// notificaciones, y decide cuándo hay que vigilar la ubicación y con qué precisión.
@MainActor
@Observable
final class AlarmEngine {
    static let shared = AlarmEngine()

    let store: AlarmStore
    let location: LocationService
    let sound: AlarmSoundPlayer
    let notifications: NotificationService

    private(set) var currentLocation: CLLocation?
    private(set) var gpsSignalLost = false
    private(set) var monitoringStartedAt: Date?
    /// Alarma que la interfaz debe destacar (por ejemplo, al abrir desde una notificación).
    var highlightedAlarmID: UUID?

    /// Sin ubicación durante este tiempo con alarmas encendidas → aviso de GPS perdido.
    static let gpsLostThreshold: TimeInterval = 120
    /// Cada cuánto se reenvía la notificación mientras la alarma suena (vibra en pantalla bloqueada).
    static let ringingRenotifyInterval: TimeInterval = 45

    private var watchdogTimer: Timer?
    private var ringingTimer: Timer?
    private var isAppActive = false

    init() {
        let store = AlarmStore()
        let location = LocationService()
        let sound = AlarmSoundPlayer()
        let notifications = NotificationService()
        self.store = store
        self.location = location
        self.sound = sound
        self.notifications = notifications

        location.onLocation = { [weak self] loc in
            self?.handleLocation(loc)
        }
        location.onRegionEntered = { [weak self] identifier in
            self?.handleRegionEntered(identifier)
        }
        location.onAuthorizationChange = { [weak self] status in
            self?.handleAuthorizationChange(status)
        }
        notifications.onStopAction = { [weak self] alarmID in
            guard let self, let alarm = self.store.alarm(id: alarmID) else { return }
            self.stopRinging(alarm)
        }
        notifications.onOpenAlarm = { [weak self] alarmID in
            self?.highlightedAlarmID = alarmID
        }
    }

    // MARK: - Ciclo de vida

    /// Llamar una vez al arrancar la app. Si iOS la relanzó por un evento de ubicación,
    /// el CLLocationManager ya existe y recibirá la entrada en región.
    func start(relaunchedByLocationEvent: Bool) {
        if let last = location.lastLocation {
            currentLocation = last
        }
        refreshMonitoring()
    }

    func setAppActive(_ active: Bool) {
        isAppActive = active
        if active {
            notifications.refreshStatus()
            sound.refreshVolume()
            if highlightedAlarmID == nil, let ringing = store.ringingAlarms.first {
                highlightedAlarmID = ringing.id
            }
        }
        refreshMonitoring()
    }

    /// iOS va a cerrar la app. Si había alarmas encendidas, avisar al usuario.
    func handleWillTerminate() {
        let count = store.onAlarms.count
        if count > 0 {
            notifications.sendTerminatedWarning(alarmCount: count)
        }
        store.saveNow()
    }

    // MARK: - Acciones del usuario

    /// Crea o actualiza una alarma. Si `armNow` es verdadero, la enciende inmediatamente.
    func save(_ alarm: Alarm, armNow: Bool) {
        var alarm = alarm
        if armNow {
            alarm.status = .armed
            alarm.preAlertFired = false
            alarm.triggeredAt = nil
        } else if alarm.status == .ringing {
            alarm.status = .inactive
        }
        if store.alarm(id: alarm.id) == nil {
            store.add(alarm)
        } else {
            store.update(alarm)
        }
        store.recordHistory(SavedPlace(
            name: alarm.name,
            coordinate: alarm.coordinate,
            radiusMeters: alarm.radiusMeters
        ))
        if armNow {
            ensurePermissions()
        }
        refreshMonitoring()
    }

    func arm(_ alarm: Alarm) {
        guard alarm.status != .armed else { return }
        store.setStatus(.armed, for: alarm.id)
        notifications.clearNotifications(for: alarm.id)
        ensurePermissions()
        refreshMonitoring()
    }

    func disarm(_ alarm: Alarm) {
        guard alarm.status != .inactive else { return }
        store.setStatus(.inactive, for: alarm.id)
        notifications.clearNotifications(for: alarm.id)
        if highlightedAlarmID == alarm.id { highlightedAlarmID = nil }
        refreshMonitoring()
    }

    func toggle(_ alarm: Alarm) {
        if alarm.isOn {
            disarm(alarm)
        } else {
            arm(alarm)
        }
    }

    func stopRinging(_ alarm: Alarm) {
        disarm(alarm)
    }

    func stopAllRinging() {
        for alarm in store.ringingAlarms {
            disarm(alarm)
        }
    }

    func delete(_ alarm: Alarm) {
        notifications.clearNotifications(for: alarm.id)
        store.remove(id: alarm.id)
        if highlightedAlarmID == alarm.id { highlightedAlarmID = nil }
        refreshMonitoring()
    }

    /// Distancia actual a una alarma, si se conoce la ubicación.
    func distance(to alarm: Alarm) -> CLLocationDistance? {
        guard let currentLocation else { return nil }
        return alarm.distance(from: currentLocation)
    }

    /// Alarma encendida más cercana.
    var nearestOnAlarm: (alarm: Alarm, distance: CLLocationDistance)? {
        guard let currentLocation else { return nil }
        return store.onAlarms
            .map { ($0, $0.distance(from: currentLocation)) }
            .min { $0.1 < $1.1 }
    }

    /// Solo para el modo demostración: fija una posición sin usar el GPS.
    func seedDemoLocation(_ loc: CLLocation) {
        currentLocation = loc
    }

    // MARK: - Permisos

    func ensurePermissions() {
        guard !DemoMode.isEnabled else { return }
        if location.isNotDetermined {
            location.requestWhenInUseAuthorization()
        } else if location.authorizationStatus == .authorizedWhenInUse {
            location.requestAlwaysAuthorization()
        }
        if !location.hasPreciseLocation, location.hasWhenInUse {
            location.requestTemporaryFullAccuracy()
        }
        if notifications.authorizationStatus == .notDetermined {
            Task { await notifications.requestAuthorization() }
        }
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse, store.hasOnAlarms {
            // Pedimos "Siempre" para que el geovallado pueda relanzar la app si iOS la cierra.
            location.requestAlwaysAuthorization()
        }
        refreshMonitoring()
    }

    // MARK: - Entrada de ubicación

    private func handleLocation(_ loc: CLLocation) {
        currentLocation = loc
        if gpsSignalLost {
            gpsSignalLost = false
            notifications.clearGPSLost()
        }
        let events = AlarmEvaluator.evaluate(alarms: store.alarms, location: loc)
        for event in events {
            switch event {
            case .preAlert(let alarmID, let distance):
                guard let alarm = store.alarm(id: alarmID) else { continue }
                store.markPreAlertFired(id: alarmID)
                notifications.sendPreAlert(for: alarm, distance: distance)
            case .trigger(let alarmID, let distance):
                trigger(alarmID: alarmID, distance: distance)
            }
        }
        if store.hasOnAlarms {
            let profile = AlarmEvaluator.recommendedProfile(alarms: store.alarms, location: loc)
            location.apply(profile: profile)
        }
    }

    private func handleRegionEntered(_ identifier: String) {
        guard let alarmID = Alarm.alarmID(fromRegionIdentifier: identifier) else { return }
        var distance: CLLocationDistance?
        if let currentLocation, let alarm = store.alarm(id: alarmID) {
            distance = alarm.distance(from: currentLocation)
        }
        trigger(alarmID: alarmID, distance: distance)
    }

    private func trigger(alarmID: UUID, distance: CLLocationDistance?) {
        guard let alarm = store.alarm(id: alarmID), alarm.isArmed else { return }
        store.setStatus(.ringing, for: alarmID)
        highlightedAlarmID = alarmID
        notifications.sendAlarm(for: alarm, distance: distance)
        refreshMonitoring()
    }

    // MARK: - Estado de vigilancia (única fuente de verdad para ubicación, audio y timers)

    private func refreshMonitoring() {
        let alarms = store.alarms
        let hasOn = store.hasOnAlarms
        let hasRinging = store.hasRingingAlarms

        // En modo demostración no se toca el GPS, las regiones ni los permisos;
        // solo el audio, para que la pantalla de alarma se vea (y se oiga) en el simulador.
        if DemoMode.isEnabled {
            if hasRinging {
                sound.startAlarm()
            } else {
                sound.stopAll()
            }
            return
        }

        // Ubicación: en segundo plano si hay alarmas encendidas; solo en primer plano para el mapa.
        if hasOn {
            if monitoringStartedAt == nil { monitoringStartedAt = Date() }
            let profile = AlarmEvaluator.recommendedProfile(alarms: alarms, location: currentLocation)
            location.startUpdating(profile: profile, background: true)
        } else if isAppActive && location.hasWhenInUse {
            monitoringStartedAt = nil
            location.startUpdating(profile: .near, background: false)
        } else {
            monitoringStartedAt = nil
            location.stopUpdating()
        }
        location.syncMonitoredRegions(for: alarms)

        // Audio.
        if hasRinging {
            sound.startAlarm()
        } else if hasOn {
            if sound.mode == .alarm {
                sound.stopAlarm(resumeKeepAlive: true)
            } else {
                sound.startKeepAlive()
            }
        } else {
            sound.stopAll()
        }

        // Vigilancia de GPS y repetición de la notificación.
        if hasOn {
            startWatchdog()
        } else {
            stopWatchdog()
            gpsSignalLost = false
        }
        if hasRinging {
            startRingingTimer()
        } else {
            stopRingingTimer()
        }
    }

    // MARK: - Timers

    private func startWatchdog() {
        guard watchdogTimer == nil else { return }
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.watchdogTick()
            }
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func watchdogTick() {
        guard store.hasOnAlarms else { return }
        let reference = location.lastFixDate ?? monitoringStartedAt ?? Date()
        let elapsed = Date().timeIntervalSince(reference)
        if elapsed >= AlarmEngine.gpsLostThreshold, !gpsSignalLost {
            gpsSignalLost = true
            notifications.sendGPSLost(secondsSinceLastFix: elapsed)
        }
    }

    private func startRingingTimer() {
        guard ringingTimer == nil else { return }
        ringingTimer = Timer.scheduledTimer(
            withTimeInterval: AlarmEngine.ringingRenotifyInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.ringingTick()
            }
        }
    }

    private func stopRingingTimer() {
        ringingTimer?.invalidate()
        ringingTimer = nil
    }

    private func ringingTick() {
        let now = Date()
        for alarm in store.ringingAlarms {
            let started = alarm.triggeredAt ?? now
            if now.timeIntervalSince(started) >= AlarmDefaults.maxRingingDuration {
                // Apagado automático para no agotar la batería si nadie la detiene.
                disarm(alarm)
            } else {
                notifications.sendAlarm(for: alarm, distance: distance(to: alarm))
            }
        }
    }
}
