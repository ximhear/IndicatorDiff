import Foundation

enum DiffEngine {

    nonisolated static func diff(
        _ a: ParquetDataset,
        _ b: ParquetDataset,
        tolerance: Tolerance
    ) -> DiffResult {
        let columnsA = Set(a.columnNames)
        let columnsB = Set(b.columnNames)
        let shared = a.columnNames.filter { columnsB.contains($0) }
        let onlyA = a.columnNames.filter { !columnsB.contains($0) }
        let onlyB = b.columnNames.filter { !columnsA.contains($0) }

        let allDates = Set(a.dateIndex.keys).union(b.dateIndex.keys)
        let sortedDates = allDates.sorted()

        var entries: [RowDiffEntry] = []
        entries.reserveCapacity(sortedDates.count)

        for date in sortedDates {
            let rowA = a.dateIndex[date]
            let rowB = b.dateIndex[date]
            let key = RowKey(date: date)

            switch (rowA, rowB) {
            case (nil, nil):
                continue
            case (_, nil):
                entries.append(RowDiffEntry(key: key, status: .onlyInA, cellDiffs: []))
            case (nil, _):
                entries.append(RowDiffEntry(key: key, status: .onlyInB, cellDiffs: []))
            case (let rA?, let rB?):
                var cellDiffs: [CellDiff] = []
                cellDiffs.reserveCapacity(shared.count + onlyA.count + onlyB.count)
                var differCount = 0
                for col in shared {
                    let av = a.value(row: rA, column: col)
                    let bv = b.value(row: rB, column: col)
                    let (status, delta) = compareCells(av, bv, tolerance: tolerance)
                    if status != .same { differCount += 1 }
                    cellDiffs.append(CellDiff(
                        column: col,
                        status: status,
                        a: av,
                        b: bv,
                        typeA: a.typeLabel(for: col),
                        typeB: b.typeLabel(for: col),
                        numericDelta: delta
                    ))
                }
                for col in onlyA {
                    let av = a.value(row: rA, column: col)
                    cellDiffs.append(CellDiff(
                        column: col,
                        status: .onlyInA,
                        a: av,
                        b: .null,
                        typeA: a.typeLabel(for: col),
                        typeB: "—",
                        numericDelta: nil
                    ))
                }
                for col in onlyB {
                    let bv = b.value(row: rB, column: col)
                    cellDiffs.append(CellDiff(
                        column: col,
                        status: .onlyInB,
                        a: .null,
                        b: bv,
                        typeA: "—",
                        typeB: b.typeLabel(for: col),
                        numericDelta: nil
                    ))
                }
                let status: RowStatus = differCount == 0 ? .same : .differ(count: differCount)
                entries.append(RowDiffEntry(key: key, status: status, cellDiffs: cellDiffs))
            }
        }

        return DiffResult(
            tolerance: tolerance,
            entries: entries,
            sharedColumns: shared,
            onlyInA: onlyA,
            onlyInB: onlyB
        )
    }

    nonisolated static func compareCells(
        _ a: CellValue,
        _ b: CellValue,
        tolerance: Tolerance
    ) -> (CellStatus, NumericDelta?) {
        if a.isNull && b.isNull { return (.same, nil) }
        if a.isNull { return (.differ, nil) }
        if b.isNull { return (.differ, nil) }

        if let numeric = compareNumeric(a, b, tolerance: tolerance) {
            return numeric
        }

        switch (a, b) {
        case (.bool(let x), .bool(let y)):
            return (x == y ? .same : .differ, nil)
        case (.string(let x), .string(let y)):
            return (x == y ? .same : .differ, nil)
        case (.date(let x), .date(let y)):
            return (x == y ? .same : .differ, nil)
        case (.timestamp(let x), .timestamp(let y)):
            return (x == y ? .same : .differ, nil)
        default:
            return (.typeMismatch, nil)
        }
    }

    /// Returns a (status, delta) tuple when both values are numeric (int/double/decimal
    /// in any combination), otherwise `nil`.
    nonisolated private static func compareNumeric(
        _ a: CellValue,
        _ b: CellValue,
        tolerance: Tolerance
    ) -> (CellStatus, NumericDelta?)? {
        guard let da = a.doubleValue, let db = b.doubleValue else {
            if isNumeric(a) != isNumeric(b) {
                return isNumeric(a) || isNumeric(b) ? (.typeMismatch, nil) : nil
            }
            return nil
        }

        if da.isNaN && db.isNaN {
            return (.same, nil)
        }
        if da.isNaN != db.isNaN {
            let delta = NumericDelta(absolute: .nan, relative: nil)
            return (.differ, delta)
        }

        let absDelta = abs(da - db)
        let maxMag = max(abs(da), abs(db))
        let relDelta: Double? = maxMag == 0 ? nil : absDelta / maxMag
        let delta = NumericDelta(absolute: absDelta, relative: relDelta)

        let equal: Bool
        switch tolerance {
        case .strict:
            equal = da == db
        case .tolerant(let absTol, let relTol):
            let bound = max(absTol, relTol * maxMag)
            equal = absDelta <= bound
        }

        return (equal ? .same : .differ, delta)
    }

    nonisolated private static func isNumeric(_ v: CellValue) -> Bool {
        switch v {
        case .int, .double, .decimal: return true
        default: return false
        }
    }
}
