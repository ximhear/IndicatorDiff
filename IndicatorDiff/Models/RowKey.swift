import Foundation

/// Identifies a row for diff. Currently only the date is used, but `qualifier`
/// reserves space for a future composite key (e.g. `(date, ticker)`).
nonisolated struct RowKey: Hashable, Sendable {
    let date: Date
    let qualifier: String?

    init(date: Date, qualifier: String? = nil) {
        self.date = date
        self.qualifier = qualifier
    }
}
