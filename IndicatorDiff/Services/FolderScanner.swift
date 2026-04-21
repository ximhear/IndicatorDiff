import Foundation

enum FolderScanError: LocalizedError {
    case notADirectory(URL)
    case cannotEnumerate(URL, underlying: String)

    var errorDescription: String? {
        switch self {
        case .notADirectory(let u): return "\(u.lastPathComponent) is not a directory."
        case .cannotEnumerate(let u, let msg): return "Cannot list \(u.lastPathComponent): \(msg)"
        }
    }
}

enum FolderScanner {

    struct StemEntry: Sendable {
        let stem: String
        let url: URL
        let source: TableSource
    }

    nonisolated static func scan(folder: URL) throws -> [String: StemEntry] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
            throw FolderScanError.notADirectory(folder)
        }

        let didStartScope = folder.startAccessingSecurityScopedResource()
        defer {
            if didStartScope { folder.stopAccessingSecurityScopedResource() }
        }

        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
            )
        } catch {
            throw FolderScanError.cannotEnumerate(folder, underlying: String(describing: error))
        }

        var parquetByStem: [String: URL] = [:]
        var csvByStem: [String: URL] = [:]

        for url in contents {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile ?? false else { continue }
            guard let source = TableSource.infer(from: url) else { continue }
            let stem = url.deletingPathExtension().lastPathComponent
            switch source {
            case .parquet:
                // If multiple parquet files with same stem (unlikely), keep the first.
                if parquetByStem[stem] == nil { parquetByStem[stem] = url }
            case .csv:
                if csvByStem[stem] == nil { csvByStem[stem] = url }
            }
        }

        var result: [String: StemEntry] = [:]
        let allStems = Set(parquetByStem.keys).union(csvByStem.keys)
        for stem in allStems {
            if let p = parquetByStem[stem] {
                result[stem] = StemEntry(stem: stem, url: p, source: .parquet)
            } else if let c = csvByStem[stem] {
                result[stem] = StemEntry(stem: stem, url: c, source: .csv)
            }
        }
        return result
    }

    /// Cross-joins two scanned folders into `FilePair` entries, sorted by stem.
    nonisolated static func pair(
        folderA: [String: StemEntry],
        folderB: [String: StemEntry],
        folderAURL: URL,
        folderBURL: URL
    ) -> [FilePair] {
        let allStems = Set(folderA.keys).union(folderB.keys).sorted()
        return allStems.map { stem in
            let entryA = folderA[stem]
            let entryB = folderB[stem]
            let status: FilePairStatus
            switch (entryA, entryB) {
            case (nil, nil): status = .error("missing in both")
            case (_, nil): status = .onlyInA
            case (nil, _): status = .onlyInB
            default: status = .pending
            }
            var notes: [String] = []
            if let a = entryA, let b = entryB, a.source != b.source {
                notes.append("\(a.source.displayName) vs \(b.source.displayName)")
            }
            return FilePair(
                stem: stem,
                fileA: entryA?.url,
                fileB: entryB?.url,
                status: status,
                result: nil,
                conflictNotes: notes
            )
        }
    }
}
