import Foundation

public enum AnthropicDate {
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parses API timestamps. ISO8601DateFormatter only accepts exactly 3
    /// fractional digits, while the API sends 6 — so fractions are truncated
    /// to milliseconds before parsing.
    public static func parse(_ string: String) -> Date? {
        if let d = plain.date(from: string) { return d }
        if let d = fractional.date(from: string) { return d }
        // Truncate long fractional seconds: ".212361" -> ".212"
        if let dotRange = string.range(of: #"\.\d+"#, options: .regularExpression) {
            let fraction = string[dotRange].dropFirst()
            let truncated = string.replacingCharacters(
                in: dotRange, with: "." + fraction.prefix(3))
            return fractional.date(from: truncated)
        }
        return nil
    }
}
