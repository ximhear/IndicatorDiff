import Foundation

enum LoadError: LocalizedError {
    case securityScope(URL)
    case emptyFile
    case dateColumnNotFound(candidates: [String])
    case unsupportedDateType(column: String, typeName: String)
    case sqlError(String)

    var errorDescription: String? {
        switch self {
        case .securityScope(let url):
            return "Cannot access \(url.lastPathComponent): security-scoped resource could not be started."
        case .emptyFile:
            return "The parquet file contained no rows."
        case .dateColumnNotFound(let candidates):
            return "Could not detect a date column. Candidates: \(candidates.joined(separator: ", "))"
        case .unsupportedDateType(let column, let typeName):
            return "Column '\(column)' has unsupported date type '\(typeName)'."
        case .sqlError(let reason):
            return "DuckDB error: \(reason)"
        }
    }
}
