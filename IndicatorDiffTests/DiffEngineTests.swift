import Testing
import Foundation
@testable import IndicatorDiff

@Suite("DiffEngine")
struct DiffEngineTests {

    @Test("Identical datasets produce all-same")
    func identicalProducesSame() {
        let a = makeDataset(rows: [
            (day(2024, 1, 1), ["close": .double(100.0)]),
            (day(2024, 1, 2), ["close": .double(101.5)])
        ])
        let b = a
        let result = DiffEngine.diff(a, b, tolerance: .strict)
        #expect(result.entries.count == 2)
        #expect(result.entries.allSatisfy { $0.status == .same })
        #expect(result.onlyInA.isEmpty)
        #expect(result.onlyInB.isEmpty)
    }

    @Test("Small numeric diff: strict differs, tolerant same")
    func strictVsTolerant() {
        let a = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .double(1.0)])
        ])
        let b = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .double(1.0 + 1e-10)])
        ])
        let strict = DiffEngine.diff(a, b, tolerance: .strict)
        let tolerant = DiffEngine.diff(a, b, tolerance: .defaultTolerant)
        #expect(strict.entries.first?.status == .differ(count: 1))
        #expect(tolerant.entries.first?.status == .same)
    }

    @Test("Date only in A is flagged")
    func onlyInA() {
        let a = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .double(1)]),
            (day(2024, 1, 2), ["x": .double(2)])
        ])
        let b = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .double(1)])
        ])
        let result = DiffEngine.diff(a, b, tolerance: .strict)
        #expect(result.entries.contains(where: { $0.key.date == day(2024, 1, 2) && $0.status == .onlyInA }))
    }

    @Test("Date only in B is flagged")
    func onlyInB() {
        let a = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .double(1)])
        ])
        let b = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .double(1)]),
            (day(2024, 1, 3), ["x": .double(9)])
        ])
        let result = DiffEngine.diff(a, b, tolerance: .strict)
        #expect(result.entries.contains(where: { $0.key.date == day(2024, 1, 3) && $0.status == .onlyInB }))
    }

    @Test("Both NaN treated as same, one NaN differs")
    func nanHandling() {
        let a = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .double(.nan)]),
            (day(2024, 1, 2), ["x": .double(.nan)])
        ])
        let b = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .double(.nan)]),
            (day(2024, 1, 2), ["x": .double(1.0)])
        ])
        let result = DiffEngine.diff(a, b, tolerance: .strict)
        let entries = Dictionary(uniqueKeysWithValues: result.entries.map { ($0.key.date, $0) })
        #expect(entries[day(2024, 1, 1)]?.status == .same)
        #expect(entries[day(2024, 1, 2)]?.status == .differ(count: 1))
    }

    @Test("Null handling: both null same, one null differs")
    func nullHandling() {
        let a = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .null]),
            (day(2024, 1, 2), ["x": .null])
        ])
        let b = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .null]),
            (day(2024, 1, 2), ["x": .double(1.0)])
        ])
        let result = DiffEngine.diff(a, b, tolerance: .strict)
        let entries = Dictionary(uniqueKeysWithValues: result.entries.map { ($0.key.date, $0) })
        #expect(entries[day(2024, 1, 1)]?.status == .same)
        #expect(entries[day(2024, 1, 2)]?.status == .differ(count: 1))
    }

    @Test("Type mismatch between double and string")
    func typeMismatch() {
        let a = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .double(1.0)])
        ], columnTypes: ["x": .double])
        let b = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .string("1.0")])
        ], columnTypes: ["x": .string])
        let result = DiffEngine.diff(a, b, tolerance: .strict)
        let cell = result.entries.first?.cellDiffs.first
        #expect(cell?.status == .typeMismatch)
    }

    @Test("Column set diff: shared vs only-in-A vs only-in-B")
    func columnSetDiff() {
        let a = makeDataset(rows: [
            (day(2024, 1, 1), ["close": .double(1), "rsi": .double(50)])
        ])
        let b = makeDataset(rows: [
            (day(2024, 1, 1), ["close": .double(1), "macd": .double(0.2)])
        ])
        let result = DiffEngine.diff(a, b, tolerance: .strict)
        #expect(result.sharedColumns == ["close"])
        #expect(result.onlyInA == ["rsi"])
        #expect(result.onlyInB == ["macd"])
    }

    @Test("Row cellDiffs include onlyInA/B columns but row count excludes them")
    func rowCellDiffsIncludeOnlyInABColumns() {
        let a = makeDataset(rows: [
            (day(2024, 1, 1), ["close": .double(1), "rsi": .double(50)])
        ])
        let b = makeDataset(rows: [
            (day(2024, 1, 1), ["close": .double(1), "macd": .double(0.2)])
        ])
        let result = DiffEngine.diff(a, b, tolerance: .strict)
        let entry = result.entries.first!
        // Shared column "close" is same → row status is .same
        #expect(entry.status == .same)
        // cellDiffs should include: close (shared), rsi (onlyInA), macd (onlyInB)
        #expect(entry.cellDiffs.count == 3)
        let byStatus = Dictionary(grouping: entry.cellDiffs, by: { $0.status })
        #expect(byStatus[.same]?.first?.column == "close")
        #expect(byStatus[.onlyInA]?.first?.column == "rsi")
        #expect(byStatus[.onlyInB]?.first?.column == "macd")
        // onlyInA cell has A value and null B
        let rsi = byStatus[.onlyInA]!.first!
        #expect(!rsi.a.isNull)
        #expect(rsi.b.isNull)
    }

    @Test("Integer and double are comparable numerically")
    func intDoubleNumericComparable() {
        let a = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .int(5)])
        ], columnTypes: ["x": .int])
        let b = makeDataset(rows: [
            (day(2024, 1, 1), ["x": .double(5.0)])
        ], columnTypes: ["x": .double])
        let result = DiffEngine.diff(a, b, tolerance: .strict)
        #expect(result.entries.first?.status == .same)
    }

    // MARK: - Helpers

    private enum ColType { case bool, int, double, decimal, string, date, timestamp }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        return calendar.date(from: comps)!
    }

    private func makeDataset(
        rows: [(Date, [String: CellValue])],
        columnTypes: [String: ColType] = [:]
    ) -> ParquetDataset {
        var columnNames: [String] = []
        var columns: [String: ColumnBuffer] = [:]
        var dates: [Date] = []
        var dateIndex: [Date: Int] = [:]

        var seenColumns: [String] = []
        for (_, cells) in rows {
            for key in cells.keys where !seenColumns.contains(key) {
                seenColumns.append(key)
            }
        }
        columnNames = seenColumns

        let rowCount = rows.count

        for col in columnNames {
            let resolvedType = columnTypes[col] ?? inferType(column: col, rows: rows)
            switch resolvedType {
            case .bool:
                var arr: [Bool?] = []
                for (_, cells) in rows {
                    if case .bool(let v) = cells[col] { arr.append(v) } else { arr.append(nil) }
                }
                columns[col] = .bool(arr)
            case .int:
                var arr: [Int64?] = []
                for (_, cells) in rows {
                    if case .int(let v) = cells[col] { arr.append(v) } else { arr.append(nil) }
                }
                columns[col] = .int(arr)
            case .double:
                var arr: [Double?] = []
                for (_, cells) in rows {
                    if case .double(let v) = cells[col] { arr.append(v) } else { arr.append(nil) }
                }
                columns[col] = .double(arr)
            case .decimal:
                var arr: [Decimal?] = []
                for (_, cells) in rows {
                    if case .decimal(let v) = cells[col] { arr.append(v) } else { arr.append(nil) }
                }
                columns[col] = .decimal(arr)
            case .string:
                var arr: [String?] = []
                for (_, cells) in rows {
                    if case .string(let v) = cells[col] { arr.append(v) } else { arr.append(nil) }
                }
                columns[col] = .string(arr)
            case .date:
                var arr: [Date?] = []
                for (_, cells) in rows {
                    if case .date(let v) = cells[col] { arr.append(v) } else { arr.append(nil) }
                }
                columns[col] = .date(arr)
            case .timestamp:
                var arr: [Date?] = []
                for (_, cells) in rows {
                    if case .timestamp(let v) = cells[col] { arr.append(v) } else { arr.append(nil) }
                }
                columns[col] = .timestamp(arr)
            }
        }

        for (i, (d, _)) in rows.enumerated() {
            dates.append(d)
            if dateIndex[d] == nil { dateIndex[d] = i }
        }

        return ParquetDataset(
            sourceURL: URL(fileURLWithPath: "/tmp/fake.parquet"),
            source: .parquet,
            dateColumn: "date" as String?,
            dates: dates,
            dateIndex: dateIndex,
            duplicateDateCount: 0,
            rowCount: rowCount,
            columnNames: columnNames,
            columns: columns
        )
    }

    private func inferType(column: String, rows: [(Date, [String: CellValue])]) -> ColType {
        for (_, cells) in rows {
            switch cells[column] {
            case .bool: return .bool
            case .int: return .int
            case .double: return .double
            case .decimal: return .decimal
            case .string: return .string
            case .date: return .date
            case .timestamp: return .timestamp
            case .null, .none: continue
            }
        }
        return .double
    }
}
