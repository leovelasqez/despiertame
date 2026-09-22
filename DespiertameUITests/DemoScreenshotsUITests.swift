import XCTest

/// Recorrido automático por la app en modo demostración para generar capturas de pantalla
/// (y, desde CI, un vídeo). Las capturas se guardan en `SCREENSHOT_DIR` o, por defecto,
/// en /tmp/despiertame-screenshots del Mac que ejecuta el simulador.
final class DemoScreenshotsUITests: XCTestCase {
    private var outputDir: URL!

    override func setUpWithError() throws {
        continueAfterFailure = true
        let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"].flatMap { $0.isEmpty ? nil : $0 }
            ?? "/tmp/despiertame-screenshots"
        outputDir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String, settle: UInt32 = 3) {
        sleep(settle) // dejar que el mapa y las animaciones terminen
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: outputDir.appendingPathComponent("\(name).png"))
    }

    private func tapIfPossible(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        guard element.waitForExistence(timeout: timeout), element.isHittable else { return false }
        element.tap()
        return true
    }

    func test01_RecorridoPrincipal() {
        let app = launch(["--demo"])
        XCTAssertTrue(app.navigationBars["Despiértame"].waitForExistence(timeout: 20))
        snap(app, "01-inicio", settle: 5)

        // Editor de nueva alarma.
        XCTAssertTrue(tapIfPossible(app.buttons["Nueva alarma"].firstMatch))
        XCTAssertTrue(app.navigationBars["Nueva alarma"].waitForExistence(timeout: 10))
        snap(app, "02-nueva-alarma", settle: 5)
        if tapIfPossible(app.buttons["Usar el centro del mapa"]) {
            snap(app, "03-nueva-alarma-con-destino", settle: 5)
        }
        // Búsqueda de lugares.
        if tapIfPossible(app.buttons["Buscar dirección o lugar"]) {
            XCTAssertTrue(app.navigationBars["Buscar destino"].waitForExistence(timeout: 10))
            snap(app, "04-buscar-destino")
            _ = tapIfPossible(app.buttons["Cancelar"].firstMatch)
        }
        _ = tapIfPossible(app.buttons["Cancelar"].firstMatch)

        // Ajustes.
        XCTAssertTrue(tapIfPossible(app.buttons["Ajustes"].firstMatch))
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 10))
        snap(app, "05-ajustes")
        _ = tapIfPossible(app.buttons["Listo"])

        // Favoritos y recientes.
        XCTAssertTrue(tapIfPossible(app.buttons["Favoritos"].firstMatch))
        XCTAssertTrue(app.navigationBars["Favoritos y recientes"].waitForExistence(timeout: 10))
        snap(app, "06-favoritos-y-recientes")
    }

    func test02_AlarmaSonando() {
        let app = launch(["--demo", "--demo-ringing"])
        XCTAssertTrue(app.staticTexts["¡Despierta!"].waitForExistence(timeout: 20))
        snap(app, "07-alarma-sonando", settle: 4)
        XCTAssertTrue(tapIfPossible(app.buttons["Detener alarma"]))
        XCTAssertTrue(app.navigationBars["Despiértame"].waitForExistence(timeout: 10))
        snap(app, "08-inicio-tras-detener", settle: 4)
    }
}
