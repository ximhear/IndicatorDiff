import Foundation

nonisolated enum TableSource: Sendable, Equatable {
    case parquet
    case csv

    static func infer(from url: URL) -> TableSource? {
        switch url.pathExtension.lowercased() {
        case "parquet", "pq": return .parquet
        case "csv", "tsv", "txt": return .csv
        default: return nil
        }
    }

    var readFunction: String {
        switch self {
        case .parquet: return "read_parquet"
        case .csv: return "read_csv_auto"
        }
    }

    var displayName: String {
        switch self {
        case .parquet: return "parquet"
        case .csv: return "csv"
        }
    }
}
