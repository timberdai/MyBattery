// SPDX-License-Identifier: MPL-2.0
import Foundation

enum StatusItemLanguage {
    static let chinese = Locale.preferredLanguages.first?.lowercased()
        .replacingOccurrences(of: "_", with: "-").split(separator: "-").first == "zh"
    static func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }
}
