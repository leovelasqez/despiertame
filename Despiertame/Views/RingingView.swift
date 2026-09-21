import SwiftUI

/// Pantalla completa mientras suena la alarma. Solo se cierra al detenerla.
struct RingingView: View {
    @Environment(AlarmEngine.self) private var engine
    @Environment(AlarmStore.self) private var store

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.85, green: 0.15, blue: 0.15), Color(red: 0.98, green: 0.45, blue: 0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 20)

                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)

                Text("¡Despierta!")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                VStack(spacing: 18) {
                    ForEach(store.ringingAlarms) { alarm in
                        VStack(spacing: 6) {
                            Text("Estás llegando a")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.85))
                            Text(alarm.name)
                                .font(.title.bold())
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            if let distance = engine.distance(to: alarm) {
                                Text("a \(DistanceFormat.string(distance)) del destino")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                if engine.sound.isVolumeLow {
                    Label("Sube el volumen del iPhone para oír mejor la alarma", systemImage: "speaker.wave.1")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 24)
                }

                if let error = engine.sound.lastErrorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    engine.stopAllRinging()
                } label: {
                    Text("Detener alarma")
                        .font(.title2.bold())
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .interactiveDismissDisabled()
        .statusBarHidden(true)
    }
}
