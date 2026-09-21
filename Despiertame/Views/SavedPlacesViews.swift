import SwiftUI
import CoreLocation

/// Gestión de favoritos y recientes, con activación de alarma en un toque.
struct FavoritesView: View {
    @Environment(AlarmEngine.self) private var engine
    @Environment(AlarmStore.self) private var store

    @State private var renaming: SavedPlace?
    @State private var renameText = ""
    @State private var confirmClearHistory = false

    var body: some View {
        List {
            Section {
                if store.favorites.isEmpty {
                    Text("Aún no tienes favoritos. Al crear una alarma, activa \"Guardar destino en favoritos\", o guarda un destino reciente desde aquí.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.favorites) { place in
                        SavedPlaceRow(place: place, icon: "star.fill", color: .yellow) {
                            activateAlarm(at: place)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                store.removeFavorite(id: place.id)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            Button {
                                renameText = place.name
                                renaming = place
                            } label: {
                                Label("Renombrar", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            } header: {
                Text("Favoritos")
            } footer: {
                Text("Toca \"Activar\" para crear y encender una alarma en ese destino con el último radio usado.")
            }

            Section {
                if store.history.isEmpty {
                    Text("Los destinos que uses aparecerán aquí.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.history) { place in
                        SavedPlaceRow(place: place, icon: "clock", color: .secondary) {
                            activateAlarm(at: place)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                store.removeHistory(id: place.id)
                            } label: {
                                Label("Quitar", systemImage: "trash")
                            }
                            Button {
                                store.addFavorite(place)
                            } label: {
                                Label("Favorito", systemImage: "star")
                            }
                            .tint(.yellow)
                        }
                    }
                    Button(role: .destructive) {
                        confirmClearHistory = true
                    } label: {
                        Label("Borrar historial", systemImage: "trash")
                    }
                }
            } header: {
                Text("Recientes")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Favoritos y recientes")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Renombrar favorito", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Nombre", text: $renameText)
            Button("Guardar") {
                if let renaming {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        store.renameFavorite(id: renaming.id, name: trimmed)
                    }
                }
                renaming = nil
            }
            Button("Cancelar", role: .cancel) { renaming = nil }
        }
        .confirmationDialog("¿Borrar todo el historial?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
            Button("Borrar historial", role: .destructive) {
                store.clearHistory()
            }
        }
    }

    private func activateAlarm(at place: SavedPlace) {
        let alarm = Alarm(
            name: place.name,
            coordinate: place.coordinate,
            radiusMeters: place.radiusMeters
        )
        engine.save(alarm, armNow: true)
    }
}

struct SavedPlaceRow: View {
    let place: SavedPlace
    let icon: String
    let color: Color
    let onActivate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .lineLimit(1)
                Text(place.subtitle.isEmpty ? "Radio \(DistanceFormat.string(place.radiusMeters))" : "\(place.subtitle) · Radio \(DistanceFormat.string(place.radiusMeters))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Activar", action: onActivate)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}

/// Selector simple de favoritos/recientes para el editor de alarmas.
struct SavedPlacePickerView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let onSelect: (SavedPlace) -> Void

    var body: some View {
        NavigationStack {
            List {
                if !store.favorites.isEmpty {
                    Section("Favoritos") {
                        ForEach(store.favorites) { place in
                            pickerRow(place, icon: "star.fill", color: .yellow)
                        }
                    }
                }
                if !store.history.isEmpty {
                    Section("Recientes") {
                        ForEach(store.history) { place in
                            pickerRow(place, icon: "clock", color: .secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Elegir destino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func pickerRow(_ place: SavedPlace, icon: String, color: Color) -> some View {
        Button {
            onSelect(place)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(place.subtitle.isEmpty ? "Radio \(DistanceFormat.string(place.radiusMeters))" : place.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
