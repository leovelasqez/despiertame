import Foundation

/// Formateo de distancias en el idioma del dispositivo ("350 m", "2,4 km").
enum DistanceFormat {
    static func string(_ meters: Double) -> String {
        guard meters.isFinite else { return "—" }
        let value = max(0, meters)
        if value < 1_000 {
            let rounded = value < 100 ? value.rounded() : (value / 10).rounded() * 10
            return Measurement(value: rounded, unit: UnitLength.meters)
                .formatted(.measurement(
                    width: .abbreviated,
                    usage: .asProvided,
                    numberFormatStyle: .number.precision(.fractionLength(0))
                ))
        }
        let km = Measurement(value: value, unit: UnitLength.meters).converted(to: .kilometers)
        let fraction: Int = km.value >= 10 ? 0 : 1
        return km.formatted(.measurement(
            width: .abbreviated,
            usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0...fraction))
        ))
    }

    /// Precisión GPS: "±15 m".
    static func accuracy(_ meters: Double) -> String {
        guard meters >= 0, meters.isFinite else { return "GPS sin señal" }
        return "±\(string(meters))"
    }

    /// Velocidad en km/h a partir de m/s.
    static func speed(_ metersPerSecond: Double) -> String {
        guard metersPerSecond >= 0, metersPerSecond.isFinite else { return "—" }
        let kmh = Measurement(value: metersPerSecond, unit: UnitSpeed.metersPerSecond)
            .converted(to: .kilometersPerHour)
        return kmh.formatted(.measurement(
            width: .abbreviated,
            usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0))
        ))
    }
}
