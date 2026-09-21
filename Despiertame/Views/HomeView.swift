import SwiftUI
import MapKit

struct HomeView: View {
    @Environment(AlarmEngine.self) private var engine
    @Environment(AlarmStore.self) private var store

    @State private var editingAlarm: Alarm?
    @State private var showingNewAlarm = false
    @State private var showingSettings = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    overviewMap
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if store.hasOnAlarms {
                    Section {
                        MonitoringStatusCard()
                    }
                }

                PermissionsSection()

                Section {
                    if store.alarms.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.alarms) { alarm in
                            AlarmRow(alarm: alarm) {
                                editingAlarm = alarm
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    engine.delete(alarm)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                                Button {
                                    editingAlarm = alarm
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                } header: {
                    Text("Alarmas")
                } footer: {
                    if store.hasOnAlarms {
                        Text("Mientras haya alarmas encendidas, no cierres la app desde el selector de apps: puedes bloquear la pantalla o usar otras apps con normalidad.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Despiértame")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        FavoritesView()
                    } label: {
                        Label("Favoritos", systemImage: "star")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Ajustes", systemImage: "gearshape")
                    }
                    Button {
                        showingNewAlarm = true
                    } label: {
                        Label("Nueva alarma", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewAlarm) {
                AlarmEditorView(alarm: nil)
            }
            .sheet(item: $editingAlarm) { alarm in
                AlarmEditorView(alarm: alarm)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onChange(of: store.onAlarms.count) { _, count in
                cameraPosition = count > 0 ? .automatic : .userLocation(fallback: .automatic)
            }
        }
    }

    // MARK: - Subvistas

    private var overviewMap: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            ForEach(store.onAlarms) { alarm in
                Marker(alarm.name, systemImage: alarm.isRinging ? "bell.badge.fill" : "bell.fill", coordinate: alarm.coordinate)
                    .tint(alarm.isRinging ? .red : .orange)
                MapCircle(center: alarm.coordinate, radius: alarm.radiusMeters)
                    .foregroundStyle(Color.orange.opacity(0.15))
                    .stroke(Color.orange, lineWidth: 2)
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls {
            MapUserLocationButton()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.and.waves.left.and.right")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Sin alarmas")
                .font(.headline)
            Text("Crea una alarma con el destino donde quieres despertarte. Sonará al entrar en el radio que elijas, aunque el iPhone esté bloqueado o en silencio.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingNewAlarm = true
            } label: {
                Label("Nueva alarma", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Fila de alarma

struct AlarmRow: View {
    @Environment(AlarmEngine.self) private var engine

    let alarm: Alarm
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(alarm.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(alarm.isRinging ? .red : .secondary)
                            .lineLimit(1)
                        Text(detailText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("Encendida", isOn: Binding(
                get: { alarm.isOn },
                set: { _ in engine.toggle(alarm) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch alarm.status {
        case .ringing: return "bell.badge.fill"
        case .armed: return "bell.fill"
        case .inactive: return "bell.slash"
        }
    }

    private var iconColor: Color {
        switch alarm.status {
        case .ringing: return .red
        case .armed: return .orange
        case .inactive: return .secondary
        }
    }

    private var statusText: String {
        switch alarm.status {
        case .ringing:
            return "¡Sonando!"
        case .armed:
            if let distance = engine.distance(to: alarm) {
                return "Vigilando · a \(DistanceFormat.string(distance))"
            }
            return "Vigilando · esperando GPS"
        case .inactive:
            return "Apagada"
        }
    }

    private var detailText: String {
        var parts = ["Radio \(DistanceFormat.string(alarm.radiusMeters))"]
        if alarm.preAlertEnabled {
            parts.append("Pre-aviso a \(DistanceFormat.string(alarm.preAlertDistanceMeters))")
        }
        return parts.joined(separator: " · ")
    }
}
