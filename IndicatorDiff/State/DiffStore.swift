import Foundation
import Observation

enum FileSlotID: Sendable { case a, b }

enum AppMode: Sendable, Equatable { case files, folders, viewer }

enum ViewerLoadState: Sendable {
    case idle
    case loading(URL)
    case loaded(ParquetDataset)
    case failed(URL, message: String)

    var url: URL? {
        switch self {
        case .idle: return nil
        case .loading(let u): return u
        case .loaded(let ds): return ds.sourceURL
        case .failed(let u, _): return u
        }
    }

    var dataset: ParquetDataset? {
        if case .loaded(let ds) = self { return ds }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var failureMessage: String? {
        if case .failed(_, let msg) = self { return msg }
        return nil
    }
}

enum FileSlotState: Sendable {
    case idle
    case loading(URL)
    case loaded(ParquetDataset)
    case failed(URL, message: String)

    var url: URL? {
        switch self {
        case .idle: return nil
        case .loading(let u): return u
        case .loaded(let ds): return ds.sourceURL
        case .failed(let u, _): return u
        }
    }

    var dataset: ParquetDataset? {
        if case .loaded(let ds) = self { return ds }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var failureMessage: String? {
        if case .failed(_, let msg) = self { return msg }
        return nil
    }
}

enum FolderSlotState: Sendable {
    case idle
    case scanning(URL)
    case scanned(URL, entryCount: Int)
    case failed(URL, message: String)

    var url: URL? {
        switch self {
        case .idle: return nil
        case .scanning(let u): return u
        case .scanned(let u, _): return u
        case .failed(let u, _): return u
        }
    }

    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }

    var failureMessage: String? {
        if case .failed(_, let msg) = self { return msg }
        return nil
    }
}

@MainActor
@Observable
final class DiffStore {
    weak var history: ComparisonHistory?

    var mode: AppMode = .files

    // File-mode state
    var slotA: FileSlotState = .idle
    var slotB: FileSlotState = .idle

    // Folder-mode state
    var folderSlotA: FolderSlotState = .idle
    var folderSlotB: FolderSlotState = .idle
    var filePairs: [FilePair] = []
    var selectedPairID: String?
    var isBatchComparing: Bool = false
    var batchProgress: (done: Int, total: Int) = (0, 0)
    private var scannedA: [String: FolderScanner.StemEntry] = [:]
    private var scannedB: [String: FolderScanner.StemEntry] = [:]
    private var folderAScope: URL?
    private var folderBScope: URL?
    private var fileAScope: URL?
    private var fileBScope: URL?

    // Viewer-mode state
    var viewerFolderSlot: FolderSlotState = .idle
    var viewerFiles: [URL] = []
    var viewerSearchQuery: String = ""
    var viewerLoadState: ViewerLoadState = .idle
    private var viewerFolderScope: URL?
    private var viewerLoadTask: Task<Void, Never>?

    // Shared tolerance/view state
    var tolerance: Tolerance = .strict
    var toleranceAbs: Double = 1e-9
    var toleranceRel: Double = 1e-6

    var showOnlyDiffs: Bool = true
    var showColumnsOnlyInA: Bool = true
    var showColumnsOnlyInB: Bool = true
    var showPairsOnlyInA: Bool = true
    var showPairsOnlyInB: Bool = true
    var result: DiffResult?
    var isComputingDiff: Bool = false

    var selectedRowID: String?
    var selectedColumn: String?

    private var diffTask: Task<Void, Never>?
    private var pairTask: Task<Void, Never>?
    private var batchTask: Task<Void, Never>?

    // MARK: - File mode

    func setFile(_ url: URL, slot: FileSlotID) {
        switch slot {
        case .a:
            fileAScope?.stopAccessingSecurityScopedResource()
            fileAScope = url.startAccessingSecurityScopedResource() ? url : nil
            slotA = .loading(url)
        case .b:
            fileBScope?.stopAccessingSecurityScopedResource()
            fileBScope = url.startAccessingSecurityScopedResource() ? url : nil
            slotB = .loading(url)
        }
        Task { await self.loadSlot(url: url, slot: slot) }
    }

    func clearFile(slot: FileSlotID) {
        switch slot {
        case .a:
            fileAScope?.stopAccessingSecurityScopedResource()
            fileAScope = nil
            slotA = .idle
        case .b:
            fileBScope?.stopAccessingSecurityScopedResource()
            fileBScope = nil
            slotB = .idle
        }
        result = nil
        selectedRowID = nil
        selectedColumn = nil
    }

    // MARK: - Folder mode

    func setFolder(_ url: URL, slot: FileSlotID) {
        switch slot {
        case .a:
            folderAScope?.stopAccessingSecurityScopedResource()
            folderAScope = url.startAccessingSecurityScopedResource() ? url : nil
            folderSlotA = .scanning(url)
        case .b:
            folderBScope?.stopAccessingSecurityScopedResource()
            folderBScope = url.startAccessingSecurityScopedResource() ? url : nil
            folderSlotB = .scanning(url)
        }
        Task { await self.scanFolder(url: url, slot: slot) }
    }

    func clearFolder(slot: FileSlotID) {
        switch slot {
        case .a:
            folderAScope?.stopAccessingSecurityScopedResource()
            folderAScope = nil
            folderSlotA = .idle
            scannedA = [:]
        case .b:
            folderBScope?.stopAccessingSecurityScopedResource()
            folderBScope = nil
            folderSlotB = .idle
            scannedB = [:]
        }
        rebuildPairs()
    }

    func selectPair(_ id: String) {
        selectedPairID = id
        result = nil
        selectedRowID = nil
        selectedColumn = nil
        slotA = .idle
        slotB = .idle

        guard let idx = filePairs.firstIndex(where: { $0.id == id }) else { return }
        let pair = filePairs[idx]

        if let cached = pair.result {
            result = cached
            resetSelectionAfterDiff()
            return
        }

        pairTask?.cancel()
        pairTask = Task { await self.computeDiff(forPairID: id) }
    }

    func compareAll() {
        let targets = filePairs.indices.filter {
            filePairs[$0].status == .pending
        }
        guard !targets.isEmpty else { return }

        batchTask?.cancel()
        isBatchComparing = true
        batchProgress = (0, targets.count)

        batchTask = Task {
            for (n, idx) in targets.enumerated() {
                if Task.isCancelled { break }
                await Task.yield()
                let id = self.filePairs[idx].id
                await self.compareSinglePair(id: id, updateActiveResult: false)
                self.batchProgress = (n + 1, targets.count)
            }
            self.isBatchComparing = false
        }
    }

    func cancelBatch() {
        batchTask?.cancel()
        isBatchComparing = false
    }

    // MARK: - Viewer mode

    func setViewerFolder(_ url: URL) {
        viewerFolderScope?.stopAccessingSecurityScopedResource()
        viewerFolderScope = url.startAccessingSecurityScopedResource() ? url : nil
        viewerFolderSlot = .scanning(url)
        viewerFiles = []
        viewerSearchQuery = ""
        viewerLoadState = .idle
        viewerLoadTask?.cancel()
        Task { await self.scanViewerFolder(url: url) }
    }

    func clearViewerFolder() {
        viewerFolderScope?.stopAccessingSecurityScopedResource()
        viewerFolderScope = nil
        viewerFolderSlot = .idle
        viewerFiles = []
        viewerSearchQuery = ""
        viewerLoadState = .idle
        viewerLoadTask?.cancel()
    }

    func selectViewerFile(_ url: URL) {
        viewerLoadTask?.cancel()
        viewerLoadState = .loading(url)
        viewerLoadTask = Task { await self.loadViewerFile(url: url) }
    }

    var viewerFilteredFiles: [URL] {
        let q = viewerSearchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return viewerFiles }
        return viewerFiles.filter { $0.lastPathComponent.lowercased().contains(q) }
    }

    private func scanViewerFolder(url: URL) async {
        do {
            let files = try await Task.detached(priority: .userInitiated) {
                try FolderScanner.listTabularFiles(folder: url)
            }.value
            viewerFiles = files
            viewerFolderSlot = .scanned(url, entryCount: files.count)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            viewerFolderSlot = .failed(url, message: message)
        }
    }

    private func loadViewerFile(url: URL) async {
        do {
            let dataset = try await Task.detached(priority: .userInitiated) {
                try await ParquetLoader.load(url: url)
            }.value
            guard !Task.isCancelled else { return }
            viewerLoadState = .loaded(dataset)
        } catch {
            guard !Task.isCancelled else { return }
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            viewerLoadState = .failed(url, message: message)
        }
    }

    // MARK: - History restore

    func restore(_ entry: HistoryEntry) {
        let urlA = entry.slotA.resolve()
        let urlB = entry.slotB.resolve()
        let failureMessage = "이 기록은 복원할 수 없습니다 — 파일 권한이 만료되었거나 파일이 이동/삭제되었습니다. 파일을 다시 선택해 주세요."

        switch entry.mode {
        case .files:
            mode = .files
            clearFolder(slot: .a)
            clearFolder(slot: .b)
            if let urlA {
                setFile(urlA, slot: .a)
            } else {
                slotA = .failed(URL(fileURLWithPath: entry.slotA.path), message: failureMessage)
            }
            if let urlB {
                setFile(urlB, slot: .b)
            } else {
                slotB = .failed(URL(fileURLWithPath: entry.slotB.path), message: failureMessage)
            }
        case .folders:
            mode = .folders
            clearFile(slot: .a)
            clearFile(slot: .b)
            if let urlA {
                setFolder(urlA, slot: .a)
            } else {
                folderSlotA = .failed(URL(fileURLWithPath: entry.slotA.path), message: failureMessage)
            }
            if let urlB {
                setFolder(urlB, slot: .b)
            } else {
                folderSlotB = .failed(URL(fileURLWithPath: entry.slotB.path), message: failureMessage)
            }
        }
    }

    // MARK: - Tolerance

    func applyToleranceChange() {
        switch mode {
        case .files:
            recomputeDiff()
        case .folders:
            invalidateAllPairResults()
            if let id = selectedPairID {
                pairTask?.cancel()
                pairTask = Task { await self.computeDiff(forPairID: id) }
            }
        case .viewer:
            break
        }
    }

    // MARK: - Private: file mode

    private func loadSlot(url: URL, slot: FileSlotID) async {
        do {
            let dataset = try await Task.detached(priority: .userInitiated) {
                try await ParquetLoader.load(url: url)
            }.value
            switch slot {
            case .a: slotA = .loaded(dataset)
            case .b: slotB = .loaded(dataset)
            }
            recomputeDiff()
            recordFileHistoryIfReady()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            switch slot {
            case .a: slotA = .failed(url, message: message)
            case .b: slotB = .failed(url, message: message)
            }
        }
    }

    private func recordFileHistoryIfReady() {
        guard let a = slotA.dataset?.sourceURL, let b = slotB.dataset?.sourceURL else { return }
        history?.record(mode: .files, urlA: a, urlB: b)
    }

    private func recordFolderHistoryIfReady() {
        guard case .scanned(let a, _) = folderSlotA,
              case .scanned(let b, _) = folderSlotB else { return }
        history?.record(mode: .folders, urlA: a, urlB: b)
    }

    private func recomputeDiff() {
        guard let a = slotA.dataset, let b = slotB.dataset else {
            result = nil
            selectedRowID = nil
            selectedColumn = nil
            return
        }

        let activeTolerance = effectiveTolerance()

        diffTask?.cancel()
        isComputingDiff = true
        diffTask = Task { [a, b, activeTolerance] in
            let res = await Task.detached(priority: .userInitiated) {
                DiffEngine.diff(a, b, tolerance: activeTolerance)
            }.value
            guard !Task.isCancelled else { return }
            self.result = res
            self.isComputingDiff = false
            self.resetSelectionAfterDiff()
        }
    }

    // MARK: - Private: folder mode

    private func scanFolder(url: URL, slot: FileSlotID) async {
        do {
            let entries = try await Task.detached(priority: .userInitiated) {
                try FolderScanner.scan(folder: url)
            }.value
            switch slot {
            case .a:
                scannedA = entries
                folderSlotA = .scanned(url, entryCount: entries.count)
            case .b:
                scannedB = entries
                folderSlotB = .scanned(url, entryCount: entries.count)
            }
            rebuildPairs()
            recordFolderHistoryIfReady()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            switch slot {
            case .a: folderSlotA = .failed(url, message: message)
            case .b: folderSlotB = .failed(url, message: message)
            }
        }
    }

    private func rebuildPairs() {
        let aURL = folderSlotA.url ?? URL(fileURLWithPath: "/")
        let bURL = folderSlotB.url ?? URL(fileURLWithPath: "/")
        filePairs = FolderScanner.pair(
            folderA: scannedA,
            folderB: scannedB,
            folderAURL: aURL,
            folderBURL: bURL
        )
        selectedPairID = nil
        result = nil
        slotA = .idle
        slotB = .idle
        selectedRowID = nil
        selectedColumn = nil
    }

    private func invalidateAllPairResults() {
        for i in filePairs.indices {
            if filePairs[i].result != nil {
                filePairs[i].result = nil
                if case .same = filePairs[i].status { filePairs[i].status = .pending }
                if case .differ = filePairs[i].status { filePairs[i].status = .pending }
            }
        }
    }

    private func computeDiff(forPairID id: String) async {
        await compareSinglePair(id: id, updateActiveResult: true)
    }

    private struct PairOutcome: Sendable {
        let datasetA: ParquetDataset
        let datasetB: ParquetDataset
        let result: DiffResult
    }

    private func compareSinglePair(id: String, updateActiveResult: Bool) async {
        guard let idx = filePairs.firstIndex(where: { $0.id == id }) else { return }
        let pair = filePairs[idx]
        guard let urlA = pair.fileA, let urlB = pair.fileB else { return }

        filePairs[idx].status = .computing
        if updateActiveResult {
            slotA = .loading(urlA)
            slotB = .loading(urlB)
            isComputingDiff = true
        }

        let tolerance = effectiveTolerance()

        // Do all the heavy work on a background task so MainActor stays responsive.
        let outcome: Result<PairOutcome, Error> = await Task.detached(priority: .userInitiated) {
            do {
                let datasetA = try await ParquetLoader.load(url: urlA)
                try Task.checkCancellation()
                let datasetB = try await ParquetLoader.load(url: urlB)
                try Task.checkCancellation()
                let res = DiffEngine.diff(datasetA, datasetB, tolerance: tolerance)
                return .success(PairOutcome(datasetA: datasetA, datasetB: datasetB, result: res))
            } catch {
                return .failure(error)
            }
        }.value

        switch outcome {
        case .success(let o):
            guard let idx2 = filePairs.firstIndex(where: { $0.id == id }) else { return }
            let cellDiffs = o.result.entries.reduce(into: 0) { acc, e in
                if case .differ(let n) = e.status { acc += n }
            }
            let rowDiffs = o.result.entries.filter { $0.status.isDiffering }.count
            filePairs[idx2].result = o.result
            filePairs[idx2].status = rowDiffs == 0 ? .same : .differ(cellDiffs: cellDiffs, rowDiffs: rowDiffs)

            if updateActiveResult {
                slotA = .loaded(o.datasetA)
                slotB = .loaded(o.datasetB)
                isComputingDiff = false
                result = o.result
                resetSelectionAfterDiff()
            }

        case .failure(let error):
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            if let idx2 = filePairs.firstIndex(where: { $0.id == id }) {
                filePairs[idx2].status = .error(message)
            }
            if updateActiveResult {
                isComputingDiff = false
                if case .loading(let u) = slotA { slotA = .failed(u, message: message) }
                if case .loading(let u) = slotB { slotB = .failed(u, message: message) }
            }
        }
    }

    // MARK: - Private: shared

    private func effectiveTolerance() -> Tolerance {
        switch tolerance {
        case .strict: return .strict
        case .tolerant: return .tolerant(abs: toleranceAbs, rel: toleranceRel)
        }
    }

    private func resetSelectionAfterDiff() {
        guard let result else { return }
        let firstDiffering = result.entries.first(where: { $0.status.isDiffering })
        let chosen = firstDiffering ?? result.entries.first
        selectedRowID = chosen?.id
        if let chosen {
            selectedColumn = chosen.cellDiffs.first(where: { $0.status != .same })?.column
                ?? chosen.cellDiffs.first?.column
                ?? result.sharedColumns.first
        } else {
            selectedColumn = result.sharedColumns.first
        }
    }

    // MARK: - Derived

    var selectedEntry: RowDiffEntry? {
        guard let selectedRowID, let result else { return nil }
        return result.entries.first(where: { $0.id == selectedRowID })
    }

    var selectedCell: CellDiff? {
        guard let col = selectedColumn else { return nil }
        return selectedEntry?.cellDiffs.first(where: { $0.column == col })
    }

    var filteredEntries: [RowDiffEntry] {
        guard let result else { return [] }
        if showOnlyDiffs {
            return result.entries.filter { $0.status.isDiffering }
        }
        return result.entries
    }

    var filteredPairs: [FilePair] {
        filePairs.filter { pair in
            if !showPairsOnlyInA, case .onlyInA = pair.status { return false }
            if !showPairsOnlyInB, case .onlyInB = pair.status { return false }
            if showOnlyDiffs {
                switch pair.status {
                case .same: return false
                default: return true
                }
            }
            return true
        }
    }

    struct PairStatusCounts {
        var total = 0
        var pending = 0
        var same = 0
        var differ = 0
        var onlyA = 0
        var onlyB = 0
        var error = 0
    }

    var pairStatusCounts: PairStatusCounts {
        var c = PairStatusCounts()
        for p in filePairs {
            c.total += 1
            switch p.status {
            case .pending, .computing: c.pending += 1
            case .same: c.same += 1
            case .differ: c.differ += 1
            case .onlyInA: c.onlyA += 1
            case .onlyInB: c.onlyB += 1
            case .error: c.error += 1
            }
        }
        return c
    }
}
