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

    public static func weeklyReset(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX") // EN weekday is part of the game look
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE HH:mm"
        return formatter.string(from: date).uppercased()
    }
}
