/**
 L10n — đa ngôn ngữ (VI/EN) qua Localizable.xcstrings / String Catalog.
 */
import Foundation

enum L10n {
    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = String(localized: String.LocalizationValue(key))
        if args.isEmpty { return format }
        return String(format: format, locale: .current, arguments: args)
    }
}
