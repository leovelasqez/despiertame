import SwiftUI
import MapKit
import CoreLocation

/// Crear o editar una alarma: destino (mapa, búsqueda, favoritos), radio y pre-aviso.
struct AlarmEditorView: View {
    @Environment(AlarmEngine.self) private var engine
    @Environment(AlarmStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: Alarm?

    @State private var name: String
    @State private var subtitle: String = ""
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var radius: Double
    @State private var preAlertEnabled: Bool
    @State private var preAlertDistance: Double
    @State private var armNow: Bool
    @State private var saveAsFavorite = false
    @State private var cameraPosition: MapCameraPosition
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var showingSearch = false
    @State private var showingSavedPlaces = false
    @State private var isGeocoding = false
    @State private var showingInsideRadiusAlert = false
    @State private var geocodeTask: Task<Void, Never>?

    init(alarm: Alarm?) {
        existing = alarm
        _name = State(initialValue: alarm?.name ?? "")
        _coordinate = State(initialValue: alarm?.coordinate)
        _radius = State(initialValue: alarm?.radiusMeters ?? AlarmDefaults.radiusMeters)
        _preAlertEnabled = State(initialValue: alarm?.preAlertEnabled ?? AlarmDefaults.preAlertEnabled)
        let preset = AlarmEditorView.nearestPreset(alarm?.preAlertDistanceMeters ?? AlarmDefaults.preAlertDistanceMeters)
        _preAlertDistance = State(initialValue: preset)
        _armNow = State(initialValue: alarm?.isOn ?? true)
        if let alarm {
            _cameraPosition = State(initialValue: .region(AlarmEditorView.region(around: alarm.coordinate, radius: alarm.radiusMeters)))
        } else {
            _cameraPosition = State(initialValue: .userLocation(fallback: .automatic))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    mapEditor
                        .frame(height: 320)
                        .listRowInsets(EdgeInsets())
                } footer: {
                    Text("Mantén pulsado un punto del mapa para colocar el destino, o usa la búsqueda. El círculo naranja es la zona donde sonará la alarma.")
                }

                destinationSection
                radiusSection
                preAlertSection

                Section {
                    Toggle("Encender ahora", isOn: $armNow)
                    Toggle("Guardar destino en favoritos", isOn: $saveAsFavorite)
                }
            }
            .navigationTitle(existing == nil ? "Nueva alarma" : "Editar alarma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { attemptSave() }
                        .bold()
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingSearch) {
                PlaceSearchView(region: visibleRegion) { result in
                    apply(result, radiusOverride: nil)
                }
            }
            .sheet(isPresented: $showingSavedPlaces) {
                SavedPlacePickerView { place in
                    let result = PlaceResult(name: place.name, subtitle: place.subtitle, coordinate: place.coordinate)
                    apply(result, radiusOverride: place.radiusMeters)
                }
            }
            .alert("Ya estás dentro del radio", isPresented: $showingInsideRadiusAlert) {
                Button("Guardar de todos modos") { save() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Tu posición actual está dentro del radio de la alarma, así que sonaría de inmediato. Aumenta la distancia o mueve el destino.")
            }
            .onAppear {
                if existing == nil {
                    engine.ensurePermissions()
                    // Si ya conocemos la posición, empezar el mapa ahí en vez de esperar al GPS.
                    if let current = engine.currentLocation {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: current.coordinate,
                            latitudinalMeters: 4_000,
                            longitudinalMeters: 4_000
                        ))
                    }
                }
            }
        }
    }

    // MARK: - Mapa

    private var mapEditor: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                UserAnnotation()
                if let coordinate {
                    Marker(name.isEmpty ? "Destino" : name, systemImage: "bell.fill", coordinate: coordinate)
                        .tint(.orange)
                    MapCircle(center: coordinate, radius: radius)
                        .foregroundStyle(Color.orange.opacity(0.18))
                        .stroke(Color.orange, lineWidth: 2)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }
            .gesture(longPressToPlace(proxy: proxy))
            .overlay {
                // Mira central: referencia para el botón "Usar el centro del mapa".
                Image(systemName: "plus")
                    .font(.title3.weight(.light))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                Text(coordinate == nil ? "Mantén pulsado para colocar el destino" : "Mantén pulsado para mover el destino")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
    }

    private func longPressToPlace(proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onEnded { value in
                guard case .second(true, let drag) = value else { return }
                guard let point = drag?.location ?? drag?.startLocation else { return }
                guard let coord = proxy.convert(point, from: .local) else { return }
                place(coord)
            }
    }

    // MARK: - Secciones

    private var destinationSection: some View {
        Section("Destino") {
            if coordinate != nil {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name.isEmpty ? "Punto en el mapa" : name)
                            .font(.headline)
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if isGeocoding {
                        ProgressView()
                    }
                }
                TextField("Nombre de la alarma", text: $name)
                    .textInputAutocapitalization(.sentences)
            } else {
                Text("Aún no has elegido destino")
                    .foregroundStyle(.secondary)
            }
            Button {
                showingSearch = true
            } label: {
                Label("Buscar dirección o lugar", systemImage: "magnifyingglass")
            }
            Button {
                showingSavedPlaces = true
            } label: {
                Label("Elegir de favoritos o recientes", systemImage: "star")
            }
            .disabled(store.favorites.isEmpty && store.history.isEmpty)
            Button {
                useMapCenter()
            } label: {
                Label("Usar el centro del mapa", systemImage: "scope")
            }
        }
    }

    private var radiusSection: some View {
        Section {
            HStack {
                Text("Sonará a menos de")
                Spacer()
                Text(DistanceFormat.string(radius))
                    .bold()
                    .monospacedDigit()
            }
            Slider(
                value: $radius,
                in: AlarmDefaults.minRadiusMeters...AlarmDefaults.maxRadiusMeters,
                step: 50
            ) {
                Text("Radio")
            } minimumValueLabel: {
                Text(DistanceFormat.string(AlarmDefaults.minRadiusMeters)).font(.caption2)
            } maximumValueLabel: {
                Text(DistanceFormat.string(AlarmDefaults.maxRadiusMeters)).font(.caption2)
            }
            HStack {
                ForEach(AlarmDefaults.radiusPresets, id: \.self) { preset in
                    Button(DistanceFormat.string(preset)) {
                        radius = preset
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(radius == preset ? .orange : .gray)
                }
            }
            if let coordinate, let current = engine.currentLocation {
                let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: current)
                if distance <= radius {
                    Label("Ya estás dentro del radio: la alarma sonaría de inmediato.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                } else {
                    Label("Estás a \(DistanceFormat.string(distance)) del destino.", systemImage: "location")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Radio de la alarma")
        } footer: {
            Text("En bus, un radio de 500 m a 1 km suele dar tiempo de sobra para prepararte. La app anticipa unos metros según tu velocidad y la precisión del GPS.")
        }
    }

    private var preAlertSection: some View {
        Section {
            Toggle("Avisarme al acercarme", isOn: $preAlertEnabled)
            if preAlertEnabled {
                Picker("Distancia del pre-aviso", selection: $preAlertDistance) {
                    ForEach(AlarmDefaults.preAlertPresets, id: \.self) { preset in
                        Text(DistanceFormat.string(preset)).tag(preset)
                    }
                }
                if preAlertDistance <= radius {
                    Label("El pre-aviso debe ser mayor que el radio para que llegue antes que la alarma.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Pre-aviso")
        } footer: {
            Text("Una notificación suave (sin la alarma completa) cuando te estés acercando.")
        }
    }

    // MARK: - Acciones

    private var canSave: Bool {
        coordinate != nil && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func useMapCenter() {
        guard let center = visibleRegion?.center else { return }
        place(center)
    }

    private func place(_ coord: CLLocationCoordinate2D) {
        coordinate = coord
        subtitle = ""
        isGeocoding = true
        geocodeTask?.cancel()
        geocodeTask = Task {
            let result = await PlaceSearchService.reverseGeocode(coord)
            guard !Task.isCancelled else { return }
            name = result.name
            subtitle = result.subtitle
            isGeocoding = false
        }
        frame(coord)
    }

    private func apply(_ result: PlaceResult, radiusOverride: Double?) {
        geocodeTask?.cancel()
        isGeocoding = false
        coordinate = result.coordinate
        name = result.name
        subtitle = result.subtitle
        if let radiusOverride {
            radius = min(max(radiusOverride, AlarmDefaults.minRadiusMeters), AlarmDefaults.maxRadiusMeters)
        }
        frame(result.coordinate)
    }

    private func frame(_ coord: CLLocationCoordinate2D) {
        withAnimation {
            cameraPosition = .region(AlarmEditorView.region(around: coord, radius: radius))
        }
    }

    private func attemptSave() {
        guard let coordinate else { return }
        if armNow, let current = engine.currentLocation {
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: current)
            if distance <= radius {
                showingInsideRadiusAlert = true
                return
            }
        }
        save()
    }

    private func save() {
        guard let coordinate else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var alarm = existing ?? Alarm(name: trimmedName, coordinate: coordinate)
        alarm.name = trimmedName
        alarm.coordinate = coordinate
        alarm.radiusMeters = radius
        alarm.preAlertEnabled = preAlertEnabled
        alarm.preAlertDistanceMeters = preAlertDistance
        if !armNow {
            alarm.status = .inactive
        }
        engine.save(alarm, armNow: armNow)
        if saveAsFavorite {
            store.addFavorite(SavedPlace(
                name: trimmedName,
                subtitle: subtitle,
                coordinate: coordinate,
                radiusMeters: radius
            ))
        }
        dismiss()
    }

    // MARK: - Utilidades

    private static func region(around coordinate: CLLocationCoordinate2D, radius: Double) -> MKCoordinateRegion {
        let span = max(radius * 4.5, 600)
        return MKCoordinateRegion(center: coordinate, latitudinalMeters: span, longitudinalMeters: span)
    }

    private static func nearestPreset(_ value: Double) -> Double {
        AlarmDefaults.preAlertPresets.min { abs($0 - value) < abs($1 - value) } ?? AlarmDefaults.preAlertDistanceMeters
    }
}
