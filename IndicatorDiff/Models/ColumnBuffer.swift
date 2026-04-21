import Foundation

nonisolated enum ColumnBuffer: Sendable {
    case bool([Bool?])
    case int([Int64?])
    case double([Double?])
    case decimal([Decimal?])
    case string([String?])
    case date([Date?])
    case timestamp([Date?])
    case unsupported(typeName: String, count: Int)

    var count: Int {
        switch self {
        case .bool(let xs): return xs.count
        case .int(let xs): return xs.count
        case .double(let xs): return xs.count
        case .decimal(let xs): return xs.count
        case .string(let xs): return xs.count
        case .date(let xs): return xs.count
        case .timestamp(let xs): return xs.count
        case .unsupported(_, let n): return n
        }
    }

    var typeLabel: String {
        switch self {
        case .bool: return "bool"
        case .int: return "int"
        case .double: return "double"
        case .decimal: return "decimal"
        case .string: return "string"
        case .date: return "date"
        case .timestamp: return "timestamp"
        case .unsupported(let name, _): return name
        }
    }

    func value(at row: Int) -> CellValue {
        switch self {
        case .bool(let xs): return xs[row].map(CellValue.bool) ?? .null
        case .int(let xs): return xs[row].map(CellValue.int) ?? .null
        case .double(let xs): return xs[row].map(CellValue.double) ?? .null
        case .decimal(let xs): return xs[row].map(CellValue.decimal) ?? .null
        case .string(let xs): return xs[row].map(CellValue.string) ?? .null
        case .date(let xs): return xs[row].map(CellValue.date) ?? .null
        case .timestamp(let xs): return xs[row].map(CellValue.timestamp) ?? .null
        case .unsupported: return .null
        }
    }
}
