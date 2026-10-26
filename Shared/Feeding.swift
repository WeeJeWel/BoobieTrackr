import Foundation

enum FeedingKind: String, CaseIterable, Codable, Identifiable {
    case breast, pump, bottle
    var id: String { rawValue }
    var title: String {
        switch self {
        case .breast: return "Breast"
        case .pump: return "Pump"
        case .bottle: return "Bottle"
        }
    }
    var symbol: String {
        switch self {
        case .breast: return "Breast"
        case .pump: return "Pump"
        case .bottle: return "waterbottle.fill"
        }
    }
    var sides: [FeedingSide] { self == .pump ? [.left, .right, .both] : [.left, .right] }
}

enum FeedingSide: String, CaseIterable, Codable, Identifiable {
    case left, right, both
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var opposite: FeedingSide { self == .left ? .right : .left }
}

struct RunningFeed: Codable, Equatable {
    let eventID: UUID
    var startedAt: Date
}

enum FeedingCSV {
    static func string(rows: [(id: UUID, start: Date, kind: FeedingKind, side: FeedingSide?, ml: Double?, duration: Double?)]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var lines = ["id,start_time_utc,type,side,volume_ml,duration_seconds"]
        for row in rows.sorted(by: { $0.start < $1.start }) {
            let fields = [row.id.uuidString, formatter.string(from: row.start), row.kind.title,
                          row.kind == .bottle ? "" : row.side?.title ?? "",
                          row.ml.map { String($0) } ?? "", row.duration.map { String(Int($0)) } ?? ""]
            lines.append(fields.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }
}
