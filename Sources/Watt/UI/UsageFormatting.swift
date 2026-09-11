import Foundation
import WattCore

enum UsageFormatting {
    static func resetText(for limit: UsageLimit, now: Date = .now) -> String {
        guard let reset = limit.resetDate else { return "Reset unavailable" }
        if reset <= now { return "Resetting soon" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: reset, relativeTo: now)
        let exact: String
        if Calendar.autoupdatingCurrent.isDate(reset, inSameDayAs: now) {
            exact = reset.formatted(date: .omitted, time: .shortened)
        } else {
            exact = reset.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        }
        return "Resets \(relative) · \(exact)"
    }
}
