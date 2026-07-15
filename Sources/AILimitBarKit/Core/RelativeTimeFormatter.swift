import Foundation

public enum RelativeTimeFormatter {
    public static func string(since date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "JUST NOW" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)M AGO" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)H AGO" : "\(hours)H \(rest)M AGO"
    }
}
