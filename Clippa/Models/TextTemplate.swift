import Foundation

struct TextTemplate: Codable, Equatable, Sendable {
    var title: String
    var folder: String
}

enum TemplateValidationError: LocalizedError {
    case emptyTitle
    case emptyBody
    case missingTemplate

    var errorDescription: String? {
        switch self {
        case .emptyTitle: String(localized: "Give your template a name.")
        case .emptyBody: String(localized: "Add some text to your template.")
        case .missingTemplate: String(localized: "This template is no longer available.")
        }
    }
}

/// A deliberately small placeholder grammar avoids treating JSON/code braces as fields.
enum TemplateRenderer {
    private static let pattern = #"\{([\p{L}_][\p{L}\p{N}_ ’'\-]{0,59})\}"#

    static func variables(in body: String) -> [String] {
        var seen = Set<String>()
        return matches(in: body).compactMap { match in
            guard let range = Range(match.range(at: 1), in: body) else { return nil }
            let name = body[range].trimmingCharacters(in: .whitespaces)
            guard automaticValue(for: name, date: Date(), locale: .current, timeZone: .current) == nil,
                  seen.insert(name).inserted else { return nil }
            return name
        }
    }

    static func render(
        _ body: String,
        values: [String: String] = [:],
        date: Date = Date(),
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        var result = body
        // Replace backwards in the original string; inserted values are never parsed again.
        for match in matches(in: body).reversed() {
            guard let nameRange = Range(match.range(at: 1), in: body),
                  let range = Range(match.range, in: result) else { continue }
            let name = body[nameRange].trimmingCharacters(in: .whitespaces)
            if let value = automaticValue(for: name, date: date, locale: locale, timeZone: timeZone) ?? values[name] {
                result.replaceSubrange(range, with: value)
            }
        }
        return result
    }

    private static func matches(in body: String) -> [NSTextCheckingResult] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        return expression.matches(in: body, range: NSRange(body.startIndex..., in: body))
    }

    private static func automaticValue(for name: String, date: Date, locale: Locale, timeZone: TimeZone) -> String? {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        switch name.lowercased() {
        case "date", "дата":
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        case "time", "час":
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        default:
            return nil
        }
        return formatter.string(from: date)
    }
}
