import Foundation
import UserNotifications
import Observation

/// Notificaciones locales: respaldo de la alarma, pre-aviso, pérdida de GPS y avisos del sistema.
@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    enum CategoryID {
        static let alarm = "ALARM"
        static let preAlert = "PRE_ALERT"
        static let system = "SYSTEM"
    }

    enum ActionID {
        static let stop = "STOP_ALARM"
    }

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// El usuario pulsó "Detener" en la notificación.
    var onStopAction: ((UUID) -> Void)?
    /// El usuario tocó la notificación (abre la app).
    var onOpenAlarm: ((UUID) -> Void)?

    private let center = UNUserNotificationCenter.current()
    private var alarmSequence = 0

    override init() {
        super.init()
        center.delegate = self
        registerCategories()
        refreshStatus()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
    }

    var isDenied: Bool { authorizationStatus == .denied }

    func refreshStatus() {
        center.getNotificationSettings { settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                self.authorizationStatus = status
            }
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        refreshStatus()
        return granted
    }

    private func registerCategories() {
        let stop = UNNotificationAction(
            identifier: ActionID.stop,
            title: "Detener alarma",
            options: [.destructive]
        )
        let alarm = UNNotificationCategory(
            identifier: CategoryID.alarm,
            actions: [stop],
            intentIdentifiers: [],
            options: []
        )
        let preAlert = UNNotificationCategory(
            identifier: CategoryID.preAlert,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let system = UNNotificationCategory(
            identifier: CategoryID.system,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([alarm, preAlert, system])
    }

    // MARK: - Envío

    /// Notificación de alarma. Se puede repetir mientras suene: cada envío usa un id nuevo.
    func sendAlarm(for alarm: Alarm, distance: Double?) {
        alarmSequence += 1
        let content = UNMutableNotificationContent()
        content.title = "¡Despierta! Llegando a \(alarm.name)"
        if let distance {
            content.body = "Estás a \(DistanceFormat.string(distance)) de tu destino. Toca para detener la alarma."
        } else {
            content.body = "Has llegado a la zona de tu destino. Toca para detener la alarma."
        }
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
        content.categoryIdentifier = CategoryID.alarm
        content.threadIdentifier = alarm.id.uuidString
        content.userInfo = ["alarmID": alarm.id.uuidString]
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(
            identifier: "alarm-\(alarm.id.uuidString)-\(alarmSequence)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func sendPreAlert(for alarm: Alarm, distance: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Te estás acercando a \(alarm.name)"
        content.body = "Quedan \(DistanceFormat.string(distance)). La alarma sonará al entrar en el radio de \(DistanceFormat.string(alarm.radiusMeters))."
        content.sound = .default
        content.categoryIdentifier = CategoryID.preAlert
        content.threadIdentifier = alarm.id.uuidString
        content.userInfo = ["alarmID": alarm.id.uuidString]
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(
            identifier: "prealert-\(alarm.id.uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func sendGPSLost(secondsSinceLastFix: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Señal GPS perdida"
        let minutes = Int(secondsSinceLastFix / 60)
        content.body = minutes >= 1
            ? "Sin ubicación desde hace \(minutes) min. La alarma podría no sonar a tiempo. Comprueba que la app siga abierta."
            : "Sin ubicación reciente. La alarma podría no sonar a tiempo. Comprueba que la app siga abierta."
        content.sound = .default
        content.categoryIdentifier = CategoryID.system
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: "gps-lost", content: content, trigger: nil)
        center.add(request)
    }

    func clearGPSLost() {
        center.removeDeliveredNotifications(withIdentifiers: ["gps-lost"])
    }

    /// Se envía si iOS cierra la app mientras hay alarmas armadas.
    func sendTerminatedWarning(alarmCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Despiértame se ha cerrado"
        content.body = alarmCount == 1
            ? "Tenías una alarma activa. Abre la app de nuevo para que siga vigilando tu destino."
            : "Tenías \(alarmCount) alarmas activas. Abre la app de nuevo para que sigan vigilando tus destinos."
        content.sound = .default
        content.categoryIdentifier = CategoryID.system
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: "app-terminated", content: content, trigger: nil)
        center.add(request)
    }

    func clearNotifications(for alarmID: UUID) {
        let idString = alarmID.uuidString
        center.getDeliveredNotifications { delivered in
            let ids = delivered
                .map { $0.request.identifier }
                .filter { $0.contains(idString) }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
        center.removePendingNotificationRequests(withIdentifiers: ["prealert-\(idString)"])
    }

    func clearAll() {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Mostrar también con la app en primer plano.
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo["alarmID"] as? String, let alarmID = UUID(uuidString: idString) else {
            return
        }
        if response.actionIdentifier == ActionID.stop {
            onStopAction?(alarmID)
        } else {
            onOpenAlarm?(alarmID)
        }
    }
}
