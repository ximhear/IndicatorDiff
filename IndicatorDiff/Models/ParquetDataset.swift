import Foundation

nonisolated struct ParquetDataset: Sendable {
    let sourceURL: URL
    let source: TableSource
    let dateColumn: String
    /// Row-order date values. `nil` entries are rows where the date column was null (skipped from index).
    let dates: [Date]
    /// Maps date → first row index that carries that date.
    let dateIndex: [Date: Int]
    /// Count of rows that share a date already present earlier — diagnostics only.
    let duplicateDateCount: Int
    /// Row count of the underlying table.
    let rowCount: Int
    /// Column name order (preserves file order).
    let columnNames: [String]
    /// Column name → typed buffer. Every buffer has `rowCount` elements.
    let columns: [String: ColumnBuffer]

    func value(row: Int, column: String) -> CellValue {
        guard let buf = columns[column] else { return .null }
        return buf.value(at: row)
    }

    func typeLabel(for column: String) -> String {
        columns[column]?.typeLabel ?? "?"
    }
}
