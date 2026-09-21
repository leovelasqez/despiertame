import Foundation
import MapKit
import CoreLocation
import Observation

/// Resultado de una búsqueda de lugar o de una geocodificación inversa.
struct PlaceResult: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var subtitle: String
    var coordinate: CLLocationCoordinate2D

    static func == (lhs: PlaceResult, rhs: PlaceResult) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Búsqueda de lugares con Apple Maps (sin API key): sugerencias mientras escribes,
/// resolución de la sugerencia a coordenadas y geocodificación inversa para el pin del mapa.
@MainActor
@Observable
final class PlaceSearchService: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var completions: [MKLocalSearchCompletion] = []
    private(set) var isResolving = false
    private(set) var errorMessage: String?

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    /// Región para priorizar resultados cercanos (la zona visible del mapa o la ubicación actual).
    func setRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }

    func updateQuery(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        if trimmed.isEmpty {
            completer.cancel()
            completions = []
        } else {
            completer.queryFragment = trimmed
        }
    }

    func clear() {
        completer.cancel()
        completions = []
        errorMessage = nil
    }

    /// Convierte una sugerencia en un lugar con coordenadas.
    func resolve(_ completion: MKLocalSearchCompletion) async -> PlaceResult? {
        isResolving = true
        defer { isResolving = false }
        let request = MKLocalSearch.Request(completion: completion)
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                errorMessage = "No se encontró ese lugar."
                return nil
            }
            var result = PlaceSearchService.makeResult(from: item)
            if result.name.isEmpty { result.name = completion.title }
            if result.subtitle.isEmpty { result.subtitle = completion.subtitle }
            return result
        } catch {
            errorMessage = "Error al buscar: \(error.localizedDescription)"
            return nil
        }
    }

    /// Búsqueda directa por texto (al pulsar "buscar" en el teclado).
    func search(text: String, near region: MKCoordinateRegion?) async -> [PlaceResult] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        isResolving = true
        defer { isResolving = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]
        if let region { request.region = region }
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.map { PlaceSearchService.makeResult(from: $0) }
        } catch {
            errorMessage = "Error al buscar: \(error.localizedDescription)"
            return []
        }
    }

    /// Nombre legible para una coordenada elegida en el mapa.
    static func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async -> PlaceResult {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let fallback = PlaceResult(
            name: "Punto en el mapa",
            subtitle: String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude),
            coordinate: coordinate
        )
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return fallback
        }
        let street = [placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        let area = [placemark.locality ?? placemark.subAdministrativeArea, placemark.administrativeArea]
            .compactMap { $0 }
            .joined(separator: ", ")
        let name = placemark.name ?? (street.isEmpty ? fallback.name : street)
        let subtitle = [street.isEmpty || street == name ? nil : street, area.isEmpty ? nil : area]
            .compactMap { $0 }
            .joined(separator: " · ")
        return PlaceResult(name: name, subtitle: subtitle.isEmpty ? fallback.subtitle : subtitle, coordinate: coordinate)
    }

    private static func makeResult(from item: MKMapItem) -> PlaceResult {
        let placemark = item.placemark
        let street = [placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        let area = [placemark.locality ?? placemark.subAdministrativeArea, placemark.administrativeArea]
            .compactMap { $0 }
            .joined(separator: ", ")
        let name = item.name ?? (street.isEmpty ? "Lugar" : street)
        let subtitle = [street.isEmpty || street == name ? nil : street, area.isEmpty ? nil : area]
            .compactMap { $0 }
            .joined(separator: " · ")
        return PlaceResult(name: name, subtitle: subtitle, coordinate: placemark.coordinate)
    }

    // MARK: - MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.completions = results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        let nsError = error as NSError
        // MKErrorDomain código 4 (placemarkNotFound) es "sin resultados": no es un error real.
        if nsError.domain == MKErrorDomain, nsError.code == MKError.placemarkNotFound.rawValue {
            Task { @MainActor in self.completions = [] }
            return
        }
        let message = error.localizedDescription
        Task { @MainActor in
            self.errorMessage = message
        }
    }
}
