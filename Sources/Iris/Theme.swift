import SwiftUI

enum Theme {
    static let canvas = Color(red: 0.020, green: 0.024, blue: 0.020)
    static let panel = Color(red: 0.031, green: 0.039, blue: 0.031)
    static let surface = Color(red: 0.063, green: 0.075, blue: 0.063)
    static let surfaceElevated = Color(red: 0.082, green: 0.098, blue: 0.082)
    static let surfaceStrong = Color(red: 0.110, green: 0.129, blue: 0.110)
    static let accent = Color(red: 1.000, green: 0.573, blue: 0.220)
    static let restorative = Color(red: 0.718, green: 0.969, blue: 0.478)
    static let progress = Color(red: 0.663, green: 0.545, blue: 1.000)
    static let text = Color(red: 0.914, green: 0.925, blue: 0.902)
    static let secondary = Color(red: 0.612, green: 0.639, blue: 0.604)
    // Raised from the Figma fallback so 9–11 pt metadata remains legible on dark cards.
    static let tertiary = Color(red: 0.486, green: 0.522, blue: 0.478)
    static let onAccent = Color(red: 0.020, green: 0.024, blue: 0.020)
    static let stroke = Color.white.opacity(0.07)

    // Compatibility aliases for the original service and exercise views.
    static let bg = panel
    static let surfaceAlt = surfaceStrong
    static let gradientTop = Color(red: 0.54, green: 0.21, blue: 0.96)
    static let gradientBottom = Color(red: 1.0, green: 0.29, blue: 0.22)
    static let saccadeLeft = Color(red: 1.0, green: 0.32, blue: 0.32)
    static let saccadeRight = Color(red: 0.30, green: 0.55, blue: 1.0)
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}

enum SettingsKeys {
    static let breakInterval = "breakInterval"       // Double, minutes
    static let autoExpand = "autoExpandOnAlert"      // Bool
    static let city = "city"                          // String
    static let useFahrenheit = "useFahrenheit"       // Bool
    static let sounds = "playSounds"                  // Bool
    static let selectedExercise = "selectedExercise" // String
    static let loopSeconds = "exerciseLoopSeconds"   // Double
    static let hasOnboarded = "hasOnboarded"         // Bool
    static let routinePreset = "routinePreset"       // String
    static let focusBreaks = "focusBreaks"           // Bool — full-screen break takeover
    static let showNotchPill = "showNotchPill"       // Bool — optional notch pill (menu-bar eye is primary)
    static let musicSupport = "musicSupport"         // Bool
}
