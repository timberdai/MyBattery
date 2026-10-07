import Foundation

/// The first system language selects the UI. Unsupported languages use English.
public enum AppLanguage: Equatable {
    case chinese, english

    public init(preferredLanguages: [String]) {
        let first = preferredLanguages.first?.lowercased().replacingOccurrences(of: "_", with: "-")
        self = first?.split(separator: "-").first == "zh" ? .chinese : .english
    }

    public static let system = AppLanguage(preferredLanguages: Locale.preferredLanguages)

    public func text(_ chinese: String, _ english: String) -> String {
        self == .chinese ? chinese : english
    }
}

public func localized(_ chinese: String, _ english: String) -> String {
    AppLanguage.system.text(chinese, english)
}
