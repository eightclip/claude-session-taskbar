import SwiftUI

enum Theme {
    // MARK: - Claude Brand Colors
    static let coral       = Color(red: 0.91, green: 0.45, blue: 0.35)    // #E87359
    static let amber       = Color(red: 0.96, green: 0.64, blue: 0.38)    // #F5A361
    static let sunset      = Color(red: 0.85, green: 0.47, blue: 0.34)    // #D97857

    // MARK: - UI Colors
    static let background    = Color(red: 0.106, green: 0.106, blue: 0.184)  // #1B1B2F
    static let card          = Color(red: 0.145, green: 0.145, blue: 0.247)  // #25253F
    static let surface       = Color(red: 0.188, green: 0.188, blue: 0.310)  // #30304F
    static let divider       = Color(red: 0.208, green: 0.208, blue: 0.333)  // #353555
    static let textPrimary   = Color.white
    static let textSecondary = Color(red: 0.545, green: 0.545, blue: 0.639)  // #8B8BA3

    // MARK: - Status Colors
    static let warning  = Color(red: 0.98, green: 0.75, blue: 0.14)   // #FAC024
    static let critical = Color(red: 0.94, green: 0.27, blue: 0.27)   // #EF4545
    static let success  = Color(red: 0.30, green: 0.78, blue: 0.47)   // #4DC778

    // MARK: - NSColor versions (for AppKit drawing)
    static let coralNS    = NSColor(red: 0.91, green: 0.45, blue: 0.35, alpha: 1)
    static let amberNS    = NSColor(red: 0.96, green: 0.64, blue: 0.38, alpha: 1)
    static let warningNS  = NSColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)
    static let criticalNS = NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)

    // MARK: - Dynamic Colors
    static func progressColors(for percentage: Double) -> [Color] {
        if percentage >= 0.85 { return [critical, Color(red: 0.86, green: 0.15, blue: 0.15)] }
        if percentage >= 0.65 { return [amber, warning] }
        return [coral, amber]
    }

    static func progressGradientNS(for percentage: Double) -> NSGradient {
        if percentage >= 0.85 {
            return NSGradient(starting: criticalNS, ending: NSColor(red: 0.86, green: 0.15, blue: 0.15, alpha: 1))!
        }
        if percentage >= 0.65 {
            return NSGradient(starting: amberNS, ending: warningNS)!
        }
        return NSGradient(starting: coralNS, ending: amberNS)!
    }

    static func progressColor(for percentage: Double) -> Color {
        if percentage >= 0.85 { return critical }
        if percentage >= 0.65 { return amber }
        return coral
    }

    // MARK: - Status Helpers
    static func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "allowed":          return success
        case "allowed_warning":  return warning
        case "rejected":         return critical
        default:                 return textSecondary
        }
    }

    static func statusLabel(for status: String) -> String {
        switch status.lowercased() {
        case "allowed":          return "Allowed"
        case "allowed_warning":  return "Warning"
        case "rejected":         return "Rate Limited"
        default:                 return "Unknown"
        }
    }

    // MARK: - Formatting Helpers
    static func formatCountdown(to date: Date) -> String {
        let seconds = Int(date.timeIntervalSinceNow)
        if seconds <= 0 { return "now" }
        let hours = seconds / 3600
        let mins = (seconds % 3600) / 60
        if hours > 24 {
            let days = hours / 24
            return "in \(days)d \(hours % 24)h"
        }
        if hours > 0 {
            return mins > 0 ? "in \(hours)h \(mins)m" : "in \(hours)h"
        }
        return "in \(mins)m"
    }

    static func formatDuration(from start: Date, to end: Date = Date()) -> String {
        let seconds = Int(end.timeIntervalSince(start))
        if seconds < 60   { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        let hours = seconds / 3600
        let mins  = (seconds % 3600) / 60
        if hours < 24 { return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h" }
        return "\(hours / 24)d ago"
    }

    static func formatTimeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 5  { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}
