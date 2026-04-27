import DuckDB
import Foundation
import os

nonisolated private let loaderLog = Logger(subsystem: "g.IndicatorDiff", category: "loader")

enum ParquetLoader {

    nonisolated private static func elapsedMs(since t: DispatchTime) -> Int {
        Int((DispatchTime.now().uptimeNanoseconds - t.uptimeNanoseconds) / 1_000_000)
    }

    nonisolated static let candidateDateNames: [String] = [
        "date", "dt", "trade_date", "tradedate", "trading_date", "날짜",
        "bas_dd", "trd_dd", "기준일자", "거래일", "거래일자"
    ]

    nonisolated static func load(
        url: URL,
        hintDateColumn: String? = nil
    ) async throws -> ParquetDataset {
        let didStartScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartScope { url.stopAccessingSecurityScopedResource() }
        }

        let tOverall = DispatchTime.now()
        loaderLog.log("load.start path=\(url.path, privacy: .public)")

        let database: Database
        let connection: Connection
        do {
            database = try Database(store: .inMemory)
            connection = try database.connect()
        } catch {
            throw LoadError.sqlError(String(describing: error))
        }

        let source = TableSource.infer(from: url) ?? .parquet
        let result: ResultSet
        let tQuery = DispatchTime.now()
        do {
            let stmt = try PreparedStatement(
                connection: connection,
                query: "SELECT * FROM \(source.readFunction)(?)"
            )
            try stmt.bind(url.path, at: 1)
            result = try stmt.execute()
        } catch {
            throw LoadError.sqlError(String(describing: error))
        }
        loaderLog.log("load.query \(elapsedMs(since: tQuery))ms rows=\(result.rowCount) cols=\(result.columnCount)")

        let rowCount = Int(result.rowCount)
        guard rowCount > 0 else { throw LoadError.emptyFile }

        let tMaterialize = DispatchTime.now()
        var columnNames: [String] = []
        columnNames.reserveCapacity(Int(result.columnCount))
        var columns: [String: ColumnBuffer] = [:]
        columns.reserveCapacity(Int(result.columnCount))

        for i in 0..<result.columnCount {
            let column = result[i]
            let name = result.columnName(at: i)
            columnNames.append(name)
            columns[name] = materialize(column: column, rowCount: rowCount)
        }
        loaderLog.log("load.materialize \(elapsedMs(since: tMaterialize))ms cols=\(result.columnCount)")

        let tDate = DispatchTime.now()
        let resolved = resolveDateColumn(
            columns: columns,
            columnNames: columnNames,
            hint: hintDateColumn
        )

        var dateIndex: [Foundation.Date: Int] = [:]
        var dates: [Foundation.Date] = []
        var duplicateDateCount = 0
        if let resolved {
            dates.reserveCapacity(rowCount)
            dateIndex.reserveCapacity(rowCount)
            for (row, maybeDate) in resolved.values.enumerated() {
                guard let d = maybeDate else { continue }
                dates.append(d)
                if dateIndex[d] == nil {
                    dateIndex[d] = row
                } else {
                    duplicateDateCount += 1
                }
            }
        }
        loaderLog.log("load.dateIndex \(elapsedMs(since: tDate))ms dateColumn=\(resolved?.name ?? "(none)", privacy: .public)")
        loaderLog.log("load.done \(elapsedMs(since: tOverall))ms total")

        return ParquetDataset(
            sourceURL: url,
            source: source,
            dateColumn: resolved?.name,
            dates: dates,
            dateIndex: dateIndex,
            duplicateDateCount: duplicateDateCount,
            rowCount: rowCount,
            columnNames: columnNames,
            columns: columns
        )
    }

    // MARK: - Column materialization

    nonisolated private static func materialize(column: Column<Void>, rowCount: Int) -> ColumnBuffer {
        let type = column.underlyingDatabaseType
        switch type {
        case .boolean:
            let c = column.cast(to: Bool.self)
            return .bool(Array(c))

        case .tinyint:
            let c = column.cast(to: Int8.self)
            return .int(c.map { $0.map(Int64.init) })
        case .smallint:
            let c = column.cast(to: Int16.self)
            return .int(c.map { $0.map(Int64.init) })
        case .integer:
            let c = column.cast(to: Int32.self)
            return .int(c.map { $0.map(Int64.init) })
        case .bigint:
            let c = column.cast(to: Int64.self)
            return .int(Array(c))
        case .utinyint:
            let c = column.cast(to: UInt8.self)
            return .int(c.map { $0.map(Int64.init) })
        case .usmallint:
            let c = column.cast(to: UInt16.self)
            return .int(c.map { $0.map(Int64.init) })
        case .uinteger:
            let c = column.cast(to: UInt32.self)
            return .int(c.map { $0.map(Int64.init) })
        case .ubigint:
            let c = column.cast(to: UInt64.self)
            return .int(c.map { raw in
                guard let v = raw, v <= UInt64(Int64.max) else { return nil }
                return Int64(v)
            })

        case .float:
            let c = column.cast(to: Float.self)
            return .double(c.map { $0.map(Double.init) })
        case .double:
            let c = column.cast(to: Double.self)
            return .double(Array(c))

        case .decimal:
            let c = column.cast(to: Decimal.self)
            return .decimal(Array(c))

        case .varchar:
            let c = column.cast(to: String.self)
            return .string(Array(c))

        case .date:
            let c = column.cast(to: DuckDB.Date.self)
            let mapped: [Foundation.Date?] = c.map { raw in
                raw.map { foundationDate(fromDuckDBDays: $0.days) }
            }
            return .date(mapped)

        case .timestamp, .timestampS, .timestampMS, .timestampNS, .timestampTz:
            let c = column.cast(to: DuckDB.Timestamp.self)
            let mapped: [Foundation.Date?] = c.map { raw in
                raw.map { foundationDate(fromDuckDBMicroseconds: $0.microseconds) }
            }
            return .timestamp(mapped)

        default:
            return .unsupported(typeName: String(describing: type), count: rowCount)
        }
    }

    nonisolated private static func foundationDate(fromDuckDBDays days: Int32) -> Foundation.Date {
        Foundation.Date(timeIntervalSince1970: TimeInterval(days) * 86_400)
    }

    nonisolated private static func foundationDate(fromDuckDBMicroseconds us: Int64) -> Foundation.Date {
        Foundation.Date(timeIntervalSince1970: TimeInterval(us) / 1_000_000.0)
    }

    // MARK: - Date column detection

    nonisolated private static func resolveDateColumn(
        columns: [String: ColumnBuffer],
        columnNames: [String],
        hint: String?
    ) -> (name: String, values: [Foundation.Date?])? {

        if let hint, let buf = columns[hint],
           let dates = datesForColumn(buf) {
            return (hint, dates)
        }

        for name in columnNames {
            guard let buf = columns[name] else { continue }
            switch buf {
            case .date(let xs): return (name, xs)
            case .timestamp(let xs): return (name, xs)
            default: break
            }
        }

        let candidateSet = Set(candidateDateNames.map { $0.lowercased() })
        for name in columnNames {
            guard candidateSet.contains(name.lowercased()) else { continue }
            guard let buf = columns[name], let dates = datesForColumn(buf) else { continue }
            return (name, dates)
        }

        return nil
    }

    nonisolated private static func datesForColumn(_ buf: ColumnBuffer) -> [Foundation.Date?]? {
        switch buf {
        case .date(let xs): return xs
        case .timestamp(let xs): return xs
        case .string(let xs): return tryParseStringDates(xs)
        case .int(let xs): return tryParseYYYYMMDD(xs)
        default: return nil
        }
    }

    nonisolated private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "yyyyMMdd",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss.SSSSSS"
        ]
        return formats.map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = fmt
            return f
        }
    }()

    nonisolated private static func tryParseStringDates(_ values: [String?]) -> [Foundation.Date?]? {
        let nonNullCount = values.lazy.compactMap { $0 }.count
        guard nonNullCount > 0 else { return nil }

        for formatter in dateFormatters {
            var parsed: [Foundation.Date?] = Array(repeating: nil, count: values.count)
            var hits = 0
            for (i, raw) in values.enumerated() {
                guard let raw else { continue }
                if let d = formatter.date(from: raw) {
                    parsed[i] = d
                    hits += 1
                }
            }
            if Double(hits) / Double(nonNullCount) >= 0.95 {
                return parsed
            }
        }
        return nil
    }

    nonisolated private static func tryParseYYYYMMDD(_ values: [Int64?]) -> [Foundation.Date?]? {
        let nonNullCount = values.lazy.compactMap { $0 }.count
        guard nonNullCount > 0 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var parsed: [Foundation.Date?] = Array(repeating: nil, count: values.count)
        var hits = 0

        for (i, raw) in values.enumerated() {
            guard let raw, raw >= 19000101, raw <= 21001231 else { continue }
            let year = Int(raw / 10000)
            let month = Int((raw / 100) % 100)
            let day = Int(raw % 100)
            guard (1...12).contains(month), (1...31).contains(day) else { continue }
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            if let d = calendar.date(from: components) {
                parsed[i] = d
                hits += 1
            }
        }
        return Double(hits) / Double(nonNullCount) >= 0.95 ? parsed : nil
    }
}
