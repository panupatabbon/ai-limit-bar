import Foundation

public enum ResetFormatter {
    public static func sessionCountdown(until: Date, from now: Date) -> String {
        let remaining = until.timeIntervalSince(now)
        if remaining <= 0 { return "NOW" }
        let totalMinutes = Int(remaining / 60)
        if totalMinutes < 1 { return "<1M" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)H \(minutes)M" : "\(minutes)M"
    }

    /// VoiceOver-friendly countdown ("resets in 2 hours 14 minutes") — the
    /// pixel labels above are visual shorthand a screen reader can't parse.
    public static func spokenSessionCountdown(until: Date, from now: Date) -> String {
        let remaining = until.timeIntervalSince(now)
        if remaining <= 0 { return "resets now" }
        let totalMinutes = Int(remaining / 60)
        if totalMinutes < 1 { return "resets in under a minute" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        return "resets in " + parts.joined(separator: " ")
    }

    /// Unlike the pixel label (24h as part of the game look), speech follows
    /// the user's locale and clock preference.
    public static func spokenWeeklyReset(_ date: Date, timeZone: TimeZone = .current,
                                         locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE jmm")
        return "resets " + formatter.string(from: date)
    }

    public static func weeklyReset(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX") // EN weekday is part of the game look
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE HH:mm"
        return formatter.string(from: date).uppercased()
    }
}
