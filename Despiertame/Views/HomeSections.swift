import SwiftUI

/// Tarjeta con el estado de la vigilancia: destino más cercano, precisión GPS y avisos.
struct MonitoringStatusCard: View {
    @Environment(AlarmEngine.self) private var engine
    @Environment(AlarmStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: store.hasRingingAlarms ? "bell.badge.fill" : "location.fill.viewfinder")
                    .foregroundStyle(store.hasRingingAlarms ? .red : .orange)
                Text(headline)
                    .font(.headline)
                Spacer()
            }

            if let nearest = engine.nearestOnAlarm {
                HStack(alignment: .firstTextBaseline) {
                    Text(DistanceFormat.string(nearest.distance))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("hasta \(nearest.alarm.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("Esperando la primera posición GPS…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                if let location = engine.currentLocation {
                    Label(DistanceFormat.accuracy(location.horizontalAccuracy), systemImage: "scope")
                    if location.speed >= 0.5 {
                        Label(DistanceFormat.speed(location.speed), systemImage: "speedometer")
                    }
                }
                Label(engine.location.currentProfile.label, systemImage: "battery.100percent")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if engine.gpsSignalLost {
                warning("Sin señal GPS desde hace más de 2 minutos. La alarma podría retrasarse.", icon: "antenna.radiowaves.left.and.right.slash")
            }
            if engine.sound.isVolumeLow {
                warning("El volumen del iPhone está bajo. Súbelo para asegurarte de oír la alarma.", icon: "speaker.wave.1")
            }
            if let error = engine.sound.lastErrorMessage {
                warning(error, icon: "exclamationmark.triangle")
            }
            if let error = engine.location.lastErrorMessage {
                warning(error, icon: "exclamationmark.triangle")
            }
        }
        .padding(.vertical, 6)
    }

    private var headline: String {
        let count = store.onAlarms.count
        if store.hasRingingAlarms { return "Alarma sonando" }
        return count == 1 ? "Vigilando 1 destino" : "Vigilando \(count) destinos"
    }

    private func warning(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote)
            .foregroundStyle(.orange)
    }
}

/// Avisos de permisos que faltan, con acceso directo a Ajustes.
struct PermissionsSection: View {
    @Environment(AlarmEngine.self) private var engine
    @Environment(AlarmStore.self) private var store

    var body: some View {
        let location = engine.location
        let notifications = engine.notifications
        let showAlwaysHint = location.authorizationStatus == .authorizedWhenInUse && store.hasOnAlarms

        if location.isDenied || !location.hasPreciseLocation && location.hasWhenInUse || showAlwaysHint || notifications.isDenied {
            Section("Permisos") {
                if location.isDenied {
                    PermissionRow(
                        icon: "location.slash",
                        color: .red,
                        title: "Ubicación desactivada",
                        message: "Sin acceso a la ubicación la alarma no puede funcionar. Actívala en Ajustes con la opción \"Siempre\" y \"Ubicación precisa\".",
                        buttonTitle: "Abrir Ajustes",
                        action: { SystemSettings.open() }
                    )
                }
                if location.hasWhenInUse && !location.hasPreciseLocation {
                    PermissionRow(
                        icon: "scope",
                        color: .orange,
                        title: "Ubicación precisa desactivada",
                        message: "Con ubicación aproximada la alarma puede sonar con varios kilómetros de error.",
                        buttonTitle: "Activar precisa",
                        action: { location.requestTemporaryFullAccuracy() }
                    )
                }
                if showAlwaysHint {
                    PermissionRow(
                        icon: "location.fill",
                        color: .blue,
                        title: "Permite la ubicación \"Siempre\"",
                        message: "Es el respaldo si iOS cierra la app: el geovallado puede relanzarla y hacer sonar la alarma. Con \"Mientras se usa\" funciona solo si la app sigue abierta en segundo plano.",
                        buttonTitle: "Abrir Ajustes",
                        action: { SystemSettings.open() }
                    )
                }
                if notifications.isDenied {
                    PermissionRow(
                        icon: "bell.slash",
                        color: .orange,
                        title: "Notificaciones desactivadas",
                        message: "La notificación es el respaldo visible de la alarma en la pantalla bloqueada. Actívalas en Ajustes.",
                        buttonTitle: "Abrir Ajustes",
                        action: { SystemSettings.open() }
                    )
                }
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let color: Color
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
