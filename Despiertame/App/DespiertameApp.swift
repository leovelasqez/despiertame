import SwiftUI

@main
struct DespiertameApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private let engine = AlarmEngine.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .environment(engine.store)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                engine.setAppActive(true)
            case .inactive:
                engine.store.saveNow()
            case .background:
                engine.setAppActive(false)
                engine.store.saveNow()
            @unknown default:
                break
            }
        }
    }
}
