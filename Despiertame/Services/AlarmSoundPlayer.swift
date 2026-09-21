import Foundation
import AVFoundation
import AudioToolbox
import Observation

/// Reproduce la alarma de forma que se escuche con el iPhone bloqueado y con el
/// interruptor en silencio.
///
/// Estrategia:
/// 1. Mientras hay alarmas armadas, mantiene la sesión de audio activa reproduciendo
///    un archivo de silencio en bucle, mezclado con otras apps (no interrumpe tu música).
///    iOS solo permite que una app empiece a sonar en segundo plano si ya estaba
///    reproduciendo audio, así que esto garantiza que la alarma pueda arrancar.
/// 2. Al disparar, cambia a la categoría de reproducción exclusiva (pausa otras apps)
///    y reproduce el tono de alarma en bucle a volumen máximo, con vibración periódica.
@MainActor
@Observable
final class AlarmSoundPlayer {
    enum Mode: Equatable {
        case idle
        case keepAlive
        case alarm
    }

    private(set) var mode: Mode = .idle
    private(set) var lastErrorMessage: String?
    /// Volumen de salida del sistema (0...1). La app no puede cambiarlo; solo avisar.
    private(set) var outputVolume: Float = AVAudioSession.sharedInstance().outputVolume

    private var keepAlivePlayer: AVAudioPlayer?
    private var alarmPlayer: AVAudioPlayer?
    private var vibrationTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let typeValue = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeIfNeeded()
            }
        })
    }

    var isAlarmSounding: Bool { mode == .alarm }
    var isVolumeLow: Bool { outputVolume < 0.5 }

    func refreshVolume() {
        outputVolume = AVAudioSession.sharedInstance().outputVolume
    }

    // MARK: - Sesión viva

    /// Mantiene la sesión de audio activa con silencio en bucle (mezclado con otras apps).
    func startKeepAlive() {
        guard mode == .idle else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let player = try makePlayer(resource: "silence")
            player.numberOfLoops = -1
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            keepAlivePlayer = player
            mode = .keepAlive
            lastErrorMessage = nil
            refreshVolume()
        } catch {
            lastErrorMessage = "No se pudo preparar el audio: \(error.localizedDescription)"
        }
    }

    // MARK: - Alarma

    func startAlarm() {
        guard mode != .alarm else { return }
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
        do {
            let session = AVAudioSession.sharedInstance()
            // Sin mixWithOthers: pausa música/podcasts para que la alarma se oiga con claridad.
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            let player = try makePlayer(resource: "alarm")
            player.numberOfLoops = -1
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            alarmPlayer = player
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "No se pudo reproducir la alarma: \(error.localizedDescription)"
        }
        mode = .alarm
        startVibration()
        refreshVolume()
    }

    /// Detiene la alarma. Si quedan alarmas armadas, vuelve al modo de sesión viva.
    func stopAlarm(resumeKeepAlive: Bool) {
        alarmPlayer?.stop()
        alarmPlayer = nil
        stopVibration()
        mode = .idle
        if resumeKeepAlive {
            startKeepAlive()
        } else {
            deactivateSession()
        }
    }

    /// Detiene todo y libera la sesión de audio.
    func stopAll() {
        alarmPlayer?.stop()
        alarmPlayer = nil
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
        stopVibration()
        mode = .idle
        deactivateSession()
    }

    // MARK: - Internos

    private enum SoundError: LocalizedError {
        case missingResource(String)
        var errorDescription: String? {
            switch self {
            case .missingResource(let name):
                return "Falta el recurso de audio \(name).wav en el paquete de la app."
            }
        }
    }

    private func makePlayer(resource: String) throws -> AVAudioPlayer {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "wav") else {
            throw SoundError.missingResource(resource)
        }
        return try AVAudioPlayer(contentsOf: url)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func startVibration() {
        stopVibration()
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
    }

    private func stopVibration() {
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }

    private func handleInterruption(typeValue: UInt?, optionsValue: UInt?) {
        guard let typeValue, let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            break
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if options.contains(.shouldResume) || mode == .alarm {
                resumeIfNeeded()
            }
        @unknown default:
            break
        }
    }

    /// Tras una llamada o un cambio de salida (auriculares), reanuda lo que estuviera sonando.
    private func resumeIfNeeded() {
        switch mode {
        case .idle:
            return
        case .keepAlive:
            try? AVAudioSession.sharedInstance().setActive(true)
            if keepAlivePlayer?.isPlaying == false { keepAlivePlayer?.play() }
        case .alarm:
            try? AVAudioSession.sharedInstance().setActive(true)
            if alarmPlayer?.isPlaying == false { alarmPlayer?.play() }
        }
    }
}
