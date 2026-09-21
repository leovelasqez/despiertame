import SwiftUI
import CoreLocation
import UserNotifications

struct SettingsView: View {
    @Environment(AlarmEngine.self) private var engine
    @Environment(AlarmStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isTestingSound = false

    var body: some View {
        NavigationStack {
            List {
                Section("Permisos") {
                    statusRow(
                        title: "Ubicación",
                        value: locationStatusText,
                        ok: engine.location.hasAlways
                    )
                    statusRow(
                        title: "Ubicación precisa",
                        value: engine.location.hasPreciseLocation ? "Activada" : "Desactivada",
                        ok: engine.location.hasPreciseLocation
                    )
                    statusRow(
                        title: "Notificaciones",
                        value: notificationStatusText,
                        ok: engine.notifications.isAuthorized
                    )
                    Button {
                        engine.ensurePermissions()
                    } label: {
                        Label("Solicitar permisos que falten", systemImage: "hand.raised")
                    }
                    Button {
                        SystemSettings.open()
                    } label: {
                        Label("Abrir Ajustes de iOS", systemImage: "gear")
                    }
                }

                Section {
                    Button {
                        testSound()
                    } label: {
                        Label(isTestingSound ? "Sonando…" : "Probar sonido de alarma (3 s)", systemImage: "speaker.wave.3")
                    }
                    .disabled(isTestingSound || store.hasRingingAlarms)
                    if engine.sound.isVolumeLow {
                        Label("El volumen del iPhone está bajo.", systemImage: "speaker.wave.1")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Sonido")
                } footer: {
                    Text("La alarma suena aunque el interruptor lateral esté en silencio, porque se reproduce como audio de la app y no como notificación. Usa el volumen de multimedia del iPhone.")
                }

                Section("Cómo funciona") {
                    infoRow(
                        icon: "location.fill.viewfinder",
                        title: "Vigilancia en segundo plano",
                        text: "Mientras haya alarmas encendidas, la app sigue recibiendo tu ubicación con la pantalla bloqueada. Verás el indicador azul de ubicación en la parte superior."
                    )
                    infoRow(
                        icon: "battery.75percent",
                        title: "Ahorro de batería",
                        text: "Lejos del destino se usa GPS de baja precisión. A menos de 3 km sube la precisión y a menos de 1 km es máxima."
                    )
                    infoRow(
                        icon: "shield.checkered",
                        title: "Respaldo por geovallado",
                        text: "Cada alarma registra además una región en iOS. Si el sistema cerrara la app, el permiso \"Siempre\" permite relanzarla al entrar en la zona."
                    )
                    infoRow(
                        icon: "xmark.app",
                        title: "No cierres la app",
                        text: "Si la cierras desde el selector de apps (deslizando hacia arriba), la vigilancia se detiene. Bloquear la pantalla o cambiar de app es seguro."
                    )
                    infoRow(
                        icon: "bell.badge",
                        title: "Notificación de respaldo",
                        text: "Al sonar, además del audio se envía una notificación con el botón \"Detener alarma\" y se repite cada 45 s mientras suene. Se apaga sola tras 15 minutos."
                    )
                }

                Section("Acerca de") {
                    LabeledContent("Versión", value: versionText)
                    LabeledContent("Alarmas guardadas", value: "\(store.alarms.count)")
                    LabeledContent("Regiones de respaldo", value: LocationService.isRegionMonitoringAvailable ? "Disponibles" : "No disponibles")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .onAppear {
                engine.notifications.refreshStatus()
                engine.sound.refreshVolume()
            }
        }
    }

    // MARK: - Filas

    private func statusRow(title: String, value: String, ok: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(ok ? Color.green : Color.orange)
        }
    }

    private func infoRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Textos

    private var locationStatusText: String {
        switch engine.location.authorizationStatus {
        case .authorizedAlways: return "Siempre"
        case .authorizedWhenInUse: return "Mientras se usa"
        case .denied: return "Denegada"
        case .restricted: return "Restringida"
        case .notDetermined: return "Sin solicitar"
        @unknown default: return "Desconocida"
        }
    }

    private var notificationStatusText: String {
        switch engine.notifications.authorizationStatus {
        case .authorized: return "Permitidas"
        case .provisional: return "Provisionales"
        case .ephemeral: return "Temporales"
        case .denied: return "Denegadas"
        case .notDetermined: return "Sin solicitar"
        @unknown default: return "Desconocidas"
        }
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    // MARK: - Acciones

    private func testSound() {
        guard !store.hasRingingAlarms else { return }
        isTestingSound = true
        engine.sound.startAlarm()
        Task {
            try? await Task.sleep(for: .seconds(3))
            engine.sound.stopAlarm(resumeKeepAlive: store.hasOnAlarms)
            isTestingSound = false
        }
    }
}
