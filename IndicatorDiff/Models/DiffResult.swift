import Foundation

nonisolated enum RowStatus: Sendable, Equatable {
    case same
    case differ(count: Int)
    case onlyInA
    case onlyInB

    var isDiffering: Bool {
        switch self {
        case .same: return false
        default: return true
        }
    }
}

nonisolated enum CellStatus: Sendable, Equatable {
    case same
    case differ
    case typeMismatch
    case onlyInA
    case onlyInB
}

nonisolated struct NumericDelta: Sendable, Equatable {
    let absolute: Double
    let relative: Double?
}

nonisolated struct CellDiff: Sendable, Identifiable {
    let column: String
    let status: CellStatus
    let a: CellValue
    let b: CellValue
    let typeA: String
    let typeB: String
    let numericDelta: NumericDelta?

    var id: String { column }
}

nonisolated struct RowDiffEntry: Sendable, Identifiable {
    let key: RowKey
    let status: RowStatus
    let cellDiffs: [CellDiff]

    var id: String {
        if let q = key.qualifier {
            return "\(key.date.timeIntervalSince1970)|\(q)"
        }
        return "\(key.date.timeIntervalSince1970)"
    }
}

nonisolated struct DiffResult: Sendable {
    let tolerance: Tolerance
    let entries: [RowDiffEntry]
    let sharedColumns: [String]
    let onlyInA: [String]
    let onlyInB: [String]

    var diffCount: Int { entries.filter { $0.status.isDiffering }.count }
}
