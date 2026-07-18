import Foundation

enum Theme: String, CaseIterable, Identifiable {
    case system = "default"
    case github
    case serif
    case sepia
    case solarizedLight = "solarized-light"
    case solarizedDark = "solarized-dark"
    case dracula
    case nord
    case tokyoNight = "tokyo-night"
    case oneDark = "one-dark"
    case oneLight = "one-light"
    case terminal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Default"
        case .github: return "GitHub"
        case .serif: return "Serif"
        case .sepia: return "Sepia"
        case .solarizedLight: return "Solarized Light"
        case .solarizedDark: return "Solarized Dark"
        case .dracula: return "Dracula"
        case .nord: return "Nord"
        case .tokyoNight: return "Tokyo Night"
        case .oneDark: return "One Dark"
        case .oneLight: return "One Light"
        case .terminal: return "Terminal"
        }
    }

    /// "light"/"dark" for fixed-appearance themes; nil for themes that follow
    /// the system appearance.
    var forcedAppearance: String? {
        switch self {
        case .system, .github, .serif: return nil
        case .sepia, .solarizedLight, .oneLight: return "light"
        case .solarizedDark, .dracula, .nord, .tokyoNight, .oneDark, .terminal: return "dark"
        }
    }

    static func current(from rawValue: String) -> Theme {
        Theme(rawValue: rawValue) ?? .system
    }
}
