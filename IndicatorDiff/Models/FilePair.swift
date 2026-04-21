import Foundation

nonisolated enum FilePairStatus: Sendable, Equatable {
    case pending
    case computing
    case same
    case differ(cellDiffs: Int, rowDiffs: Int)
    case onlyInA
    case onlyInB
    case error(String)

    var isDiffering: Bool {
        switch self {
        case .differ, .onlyInA, .onlyInB, .error: return true
        default: return false
        }
    }
}

nonisolated struct FilePair: Sendable, Identifiable {
    let stem: String
    let fileA: URL?
    let fileB: URL?
    var status: FilePairStatus
    /// Cached diff result — present only after successful comparison.
    var result: DiffResult?
    var conflictNotes: [String]

    var id: String { stem }

    var displayNameA: String {
        fileA?.lastPathComponent ?? "—"
    }

    var displayNameB: String {
        fileB?.lastPathComponent ?? "—"
    }

    var sourceA: TableSource? { fileA.flatMap(TableSource.infer(from:)) }
    var sourceB: TableSource? { fileB.flatMap(TableSource.infer(from:)) }

    /// Pair format label e.g. "parquet/csv".
    var formatLabel: String {
        let a = sourceA?.displayName ?? "—"
        let b = sourceB?.displayName ?? "—"
        return "\(a)/\(b)"
    }
}
