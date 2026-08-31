import Foundation

struct MoonInfo {
    let phaseName: String
    let illumination: Double // 0..1
    let age: Double          // days since new moon
}

enum MoonPhase {
    private static let cycle: Double = 29.53058867
    // New moon reference: 2000-01-06 18:14 UTC
    private static let reference = Date(timeIntervalSince1970: 947182440)

    static func info(for date: Date = Date()) -> MoonInfo {
        var age = date.timeIntervalSince(reference) / 86400
        age = age.truncatingRemainder(dividingBy: cycle)
        if age < 0 { age += cycle }
        let frac = age / cycle
        let illum = (1 - cos(frac * 2 * .pi)) / 2
        let idx = Int((frac * 8).rounded()) % 8
        let names = ["New Moon", "Waxing Crescent", "First Quarter",
                     "Waxing Gibbous", "Full Moon", "Waning Gibbous",
                     "Last Quarter", "Waning Crescent"]
        return MoonInfo(phaseName: names[idx], illumination: illum, age: age)
    }
}
