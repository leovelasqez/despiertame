import UIKit

/// Necesario para dos cosas que SwiftUI no cubre por sí solo:
/// 1. Crear el motor (y su CLLocationManager) en cuanto arranca la app, para que si iOS
///    la relanzó en segundo plano por una entrada en región, el evento no se pierda.
/// 2. Avisar al usuario si el sistema cierra la app con alarmas encendidas.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let relaunchedByLocation = launchOptions?[.location] != nil
        if DemoMode.isEnabled {
            DemoMode.seed(into: AlarmEngine.shared)
        }
        AlarmEngine.shared.start(relaunchedByLocationEvent: relaunchedByLocation)
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        AlarmEngine.shared.handleWillTerminate()
    }
}
