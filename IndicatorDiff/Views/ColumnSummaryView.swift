import SwiftUI

struct ColumnSummaryView: View {
    @Environment(DiffStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    private var header: some View {
        @Bindable var bindable = store
        let stats = statusCounts(for: store.selectedEntry)
        let visibleTotal = visibleCount(in: store.selectedEntry)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Columns")
                    .font(.headline)
                if stats.total > 0 {
                    Text("\(visibleTotal)/\(stats.total)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if stats.total > 0 {
                    countBadges(stats: stats)
                }
            }
            HStack(spacing: 10) {
                Toggle(isOn: $bindable.showColumnsOnlyInA) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.circle.fill")
                            .foregroundStyle(stats.onlyA == 0 ? Color.secondary : Color.orange)
                        Text("A-only")
                            .font(.caption)
                        Text("(\(stats.onlyA))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(stats.onlyA == 0)

                Toggle(isOn: $bindable.showColumnsOnlyInB) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(stats.onlyB == 0 ? Color.secondary : Color.orange)
                        Text("B-only")
                            .font(.caption)
                        Text("(\(stats.onlyB))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(stats.onlyB == 0)

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func countBadges(stats: StatusCounts) -> some View {
        HStack(spacing: 5) {
            if stats.differ > 0 {
                CountBadge(systemImage: "circle.fill", color: .red, value: stats.differ, help: "differ")
            }
            if stats.typeMismatch > 0 {
                CountBadge(systemImage: "exclamationmark.triangle.fill", color: .yellow, value: stats.typeMismatch, help: "type mismatch")
            }
            if stats.onlyA > 0 {
                CountBadge(systemImage: "arrow.left.circle.fill", color: .orange, value: stats.onlyA, help: "only in A")
            }
            if stats.onlyB > 0 {
                CountBadge(systemImage: "arrow.right.circle.fill", color: .orange, value: stats.onlyB, help: "only in B")
            }
            if stats.same > 0 {
                CountBadge(systemImage: "circle", color: .secondary, value: stats.same, help: "same")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let entry = store.selectedEntry {
            switch entry.status {
            case .onlyInA, .onlyInB:
                onlyInMessage(entry.status)
            default:
                columnTable(for: entry)
            }
        } else {
            Spacer()
            Text("왼쪽에서 날짜를 선택하세요")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func columnTable(for entry: RowDiffEntry) -> some View {
        let visible = visibleSortedCells(entry: entry)
        let selectionBinding = Binding<CellDiff.ID?>(
            get: {
                guard let col = store.selectedColumn else { return nil }
                return visible.first(where: { $0.column == col })?.id
            },
            set: { newValue in
                if let newValue, let match = visible.first(where: { $0.id == newValue }) {
                    store.selectedColumn = match.column
                }
            }
        )

        return Table(visible, selection: selectionBinding) {
            TableColumn("Status") { cell in
                statusBadge(for: cell.status)
            }
            .width(60)
            TableColumn("Column") { cell in
                Text(cell.column)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(cell.status == .same ? .secondary : .primary)
            }
            TableColumn("Δ") { cell in
                Text(deltaSummary(for: cell))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(cell.status == .same ? .secondary : .primary)
            }
            .width(min: 90)
        }
    }

    private func visibleSortedCells(entry: RowDiffEntry) -> [CellDiff] {
        entry.cellDiffs
            .filter { cell in
                switch cell.status {
                case .onlyInA: return store.showColumnsOnlyInA
                case .onlyInB: return store.showColumnsOnlyInB
                default: return true
                }
            }
            .sorted { Self.priority(of: $0.status) < Self.priority(of: $1.status) }
    }

    private func visibleCount(in entry: RowDiffEntry?) -> Int {
        guard let entry else { return 0 }
        return entry.cellDiffs.reduce(0) { acc, cell in
            switch cell.status {
            case .onlyInA: return acc + (store.showColumnsOnlyInA ? 1 : 0)
            case .onlyInB: return acc + (store.showColumnsOnlyInB ? 1 : 0)
            default: return acc + 1
            }
        }
    }

    /// Sort priority: differing rows float to the top, same rows sink.
    private static func priority(of status: CellStatus) -> Int {
        switch status {
        case .differ: return 0
        case .typeMismatch: return 1
        case .onlyInA: return 2
        case .onlyInB: return 3
        case .same: return 4
        }
    }

    private struct StatusCounts {
        var differ = 0
        var typeMismatch = 0
        var onlyA = 0
        var onlyB = 0
        var same = 0
        var total: Int { differ + typeMismatch + onlyA + onlyB + same }
    }

    private func statusCounts(for entry: RowDiffEntry?) -> StatusCounts {
        var counts = StatusCounts()
        guard let entry else { return counts }
        for cell in entry.cellDiffs {
            switch cell.status {
            case .differ: counts.differ += 1
            case .typeMismatch: counts.typeMismatch += 1
            case .onlyInA: counts.onlyA += 1
            case .onlyInB: counts.onlyB += 1
            case .same: counts.same += 1
            }
        }
        return counts
    }

    private func onlyInMessage(_ status: RowStatus) -> some View {
        let label: String = status == .onlyInA ? "이 날짜는 A 파일에만 존재" : "이 날짜는 B 파일에만 존재"
        return VStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .imageScale(.large)
                .foregroundStyle(.orange)
            Text(label)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func statusBadge(for status: CellStatus) -> some View {
        switch status {
        case .same:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .differ:
            Image(systemName: "circle.fill")
                .foregroundStyle(.red)
        case .typeMismatch:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .onlyInA:
            Image(systemName: "arrow.left.circle.fill")
                .foregroundStyle(.orange)
        case .onlyInB:
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(.orange)
        }
    }

    private func deltaSummary(for cell: CellDiff) -> String {
        switch cell.status {
        case .same: return "—"
        case .typeMismatch: return "type!"
        case .onlyInA: return "only A"
        case .onlyInB: return "only B"
        case .differ:
            guard let d = cell.numericDelta else {
                return cell.a.displayString == cell.b.displayString ? "—" : "≠"
            }
            var parts: [String] = []
            if d.absolute.isFinite {
                parts.append("abs=\(CellValue.formatDouble(d.absolute))")
            }
            if let rel = d.relative, rel.isFinite {
                parts.append("rel=\(CellValue.formatDouble(rel))")
            }
            return parts.joined(separator: " ")
        }
    }
}

private struct CountBadge: View {
    let systemImage: String
    let color: Color
    let value: Int
    let help: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .imageScale(.small)
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.semibold))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 0.5))
        .help(help)
    }
}
