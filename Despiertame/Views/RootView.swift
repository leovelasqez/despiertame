import SwiftUI

struct RootView: View {
    @Environment(AlarmEngine.self) private var engine
    @Environment(AlarmStore.self) private var store

    var body: some View {
        HomeView()
            .fullScreenCover(isPresented: ringingPresented) {
                RingingView()
            }
    }

    /// Se muestra a pantalla completa mientras haya alguna alarma sonando.
    private var ringingPresented: Binding<Bool> {
        Binding(
            get: { store.hasRingingAlarms },
            set: { presented in
                if !presented { engine.stopAllRinging() }
            }
        )
    }
}

/// Abre la pantalla de la app dentro de Ajustes de iOS.
enum SystemSettings {
    @MainActor
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
