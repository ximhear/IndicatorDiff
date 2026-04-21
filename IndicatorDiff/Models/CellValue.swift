import Foundation

nonisolated enum CellValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case decimal(Decimal)
    case string(String)
    case date(Date)
    case timestamp(Date)

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    var typeLabel: String {
        switch self {
        case .null: return "null"
        case .bool: return "bool"
        case .int: return "int"
        case .double: return "double"
        case .decimal: return "decimal"
        case .string: return "string"
        case .date: return "date"
        case .timestamp: return "timestamp"
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        case .decimal(let v): return NSDecimalNumber(decimal: v).doubleValue
        default: return nil
        }
    }

    var displayString: String {
        switch self {
        case .null: return "—"
        case .bool(let v): return v ? "true" : "false"
        case .int(let v): return String(v)
        case .double(let v):
            if v.isNaN { return "NaN" }
            if v.isInfinite { return v > 0 ? "+∞" : "-∞" }
            return Self.formatDouble(v)
        case .decimal(let v): return NSDecimalNumber(decimal: v).stringValue
        case .string(let v): return v
        case .date(let d): return Self.dateFormatter.string(from: d)
        case .timestamp(let d): return Self.timestampFormatter.string(from: d)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
        return f
    }()

    static func formatDouble(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.maximumSignificantDigits = 12
        f.minimumSignificantDigits = 1
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}
