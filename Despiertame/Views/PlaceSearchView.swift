import SwiftUI
import MapKit

/// Búsqueda de destino por texto con Apple Maps. Sin texto, muestra favoritos y recientes.
struct PlaceSearchView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let region: MKCoordinateRegion?
    let onSelect: (PlaceResult) -> Void

    @State private var search = PlaceSearchService()
    @State private var query = ""
    @State private var directResults: [PlaceResult] = []

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    savedSections
                } else {
                    resultsSections
                }
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Dirección, lugar, terminal, ciudad…"
            )
            .autocorrectionDisabled()
            .onChange(of: query) { _, newValue in
                directResults = []
                search.updateQuery(newValue)
            }
            .onSubmit(of: .search) {
                Task {
                    directResults = await search.search(text: query, near: region)
                }
            }
            .onAppear {
                if let region {
                    search.setRegion(region)
                }
            }
            .navigationTitle("Buscar destino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .overlay {
                if search.isResolving {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    @ViewBuilder
    private var savedSections: some View {
        if store.favorites.isEmpty && store.history.isEmpty {
            Section {
                Text("Escribe una dirección o el nombre de un lugar. Tus favoritos y destinos recientes aparecerán aquí.")
                    .foregroundStyle(.secondary)
            }
        }
        if !store.favorites.isEmpty {
            Section("Favoritos") {
                ForEach(store.favorites) { place in
                    placeRow(name: place.name, subtitle: place.subtitle, icon: "star.fill", color: .yellow) {
                        select(PlaceResult(name: place.name, subtitle: place.subtitle, coordinate: place.coordinate))
                    }
                }
            }
        }
        if !store.history.isEmpty {
            Section("Recientes") {
                ForEach(store.history) { place in
                    placeRow(name: place.name, subtitle: place.subtitle, icon: "clock", color: .secondary) {
                        select(PlaceResult(name: place.name, subtitle: place.subtitle, coordinate: place.coordinate))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resultsSections: some View {
        if !directResults.isEmpty {
            Section("Resultados") {
                ForEach(directResults) { result in
                    placeRow(name: result.name, subtitle: result.subtitle, icon: "mappin.circle.fill", color: .orange) {
                        select(result)
                    }
                }
            }
        }
        Section("Sugerencias") {
            if search.completions.isEmpty && directResults.isEmpty {
                Text(search.errorMessage ?? "Sigue escribiendo o pulsa buscar en el teclado…")
                    .foregroundStyle(.secondary)
            }
            ForEach(search.completions, id: \.self) { completion in
                placeRow(name: completion.title, subtitle: completion.subtitle, icon: "magnifyingglass", color: .secondary) {
                    Task {
                        if let result = await search.resolve(completion) {
                            select(result)
                        }
                    }
                }
            }
        }
    }

    private func placeRow(name: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private func select(_ result: PlaceResult) {
        onSelect(result)
        dismiss()
    }
}
