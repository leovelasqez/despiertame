import Foundation
import CoreLocation
import Observation

/// Almacén persistente de alarmas, favoritos e historial.
/// Guarda todo en un único JSON en Application Support, con escritura diferida.
@MainActor
@Observable
final class AlarmStore {
    private(set) var alarms: [Alarm] = []
    private(set) var favorites: [SavedPlace] = []
    private(set) var history: [SavedPlace] = []

    static let maxHistoryItems = 20

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    private struct Snapshot: Codable {
        var alarms: [Alarm]
        var favorites: [SavedPlace]
        var history: [SavedPlace]
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? AlarmStore.defaultFileURL()
        load()
    }

    // MARK: - Consultas

    var armedAlarms: [Alarm] { alarms.filter { $0.isArmed } }
    var ringingAlarms: [Alarm] { alarms.filter { $0.isRinging } }
    var onAlarms: [Alarm] { alarms.filter { $0.isOn } }
    var hasOnAlarms: Bool { alarms.contains { $0.isOn } }
    var hasRingingAlarms: Bool { alarms.contains { $0.isRinging } }

    func alarm(id: UUID) -> Alarm? {
        alarms.first { $0.id == id }
    }

    // MARK: - Alarmas

    func add(_ alarm: Alarm) {
        alarms.insert(alarm, at: 0)
        scheduleSave()
    }

    func update(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index] = alarm
        scheduleSave()
    }

    func remove(id: UUID) {
        alarms.removeAll { $0.id == id }
        scheduleSave()
    }

    func setStatus(_ status: AlarmStatus, for id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].status = status
        switch status {
        case .armed:
            alarms[index].preAlertFired = false
            alarms[index].triggeredAt = nil
        case .ringing:
            alarms[index].triggeredAt = Date()
        case .inactive:
            alarms[index].triggeredAt = nil
        }
        scheduleSave()
    }

    func markPreAlertFired(id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].preAlertFired = true
        scheduleSave()
    }

    // MARK: - Favoritos

    func addFavorite(_ place: SavedPlace) {
        if let index = favorites.firstIndex(where: { $0.isSameSpot(as: place) }) {
            favorites[index] = place
        } else {
            favorites.insert(place, at: 0)
        }
        scheduleSave()
    }

    func removeFavorite(id: UUID) {
        favorites.removeAll { $0.id == id }
        scheduleSave()
    }

    func renameFavorite(id: UUID, name: String) {
        guard let index = favorites.firstIndex(where: { $0.id == id }) else { return }
        favorites[index].name = name
        scheduleSave()
    }

    func favorite(near coordinate: CLLocationCoordinate2D) -> SavedPlace? {
        let probe = SavedPlace(name: "", coordinate: coordinate)
        return favorites.first { $0.isSameSpot(as: probe) }
    }

    // MARK: - Historial

    func recordHistory(_ place: SavedPlace) {
        history.removeAll { $0.isSameSpot(as: place) }
        history.insert(place, at: 0)
        if history.count > AlarmStore.maxHistoryItems {
            history = Array(history.prefix(AlarmStore.maxHistoryItems))
        }
        scheduleSave()
    }

    func removeHistory(id: UUID) {
        history.removeAll { $0.id == id }
        scheduleSave()
    }

    func clearHistory() {
        history.removeAll()
        scheduleSave()
    }

    // MARK: - Persistencia

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Despiertame", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(Snapshot.self, from: data) else { return }
        alarms = snapshot.alarms
        favorites = snapshot.favorites
        history = snapshot.history
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// Escribe inmediatamente en disco. Úsalo antes de que la app pase a segundo plano.
    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        let snapshot = Snapshot(alarms: alarms, favorites: favorites, history: history)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
