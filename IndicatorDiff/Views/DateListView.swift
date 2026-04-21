import SwiftUI

struct DateListView: View {
    @Environment(DiffStore.self) private var store

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        @Bindable var bindable = store
        let entries = store.filteredEntries

        VStack(spacing: 0) {
            header
            Divider()
            if entries.isEmpty {
                Spacer()
                Text(store.showOnlyDiffs ? "차이 없음" : "표시할 항목 없음")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Spacer()
            } else {
                List(entries, selection: $bindable.selectedRowID) { entry in
                    DateRow(entry: entry)
                        .tag(entry.id)
                }
                .listStyle(.inset)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Dates")
                .font(.headline)
            Spacer()
            if let result = store.result {
                Text("\(result.entries.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct DateRow: View {
    let entry: RowDiffEntry

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            Text(Self.dateFormatter.string(from: entry.key.date))
                .font(.system(.body, design: .monospaced))
            Spacer()
            trailingLabel
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch entry.status {
        case .same:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .differ:
            Image(systemName: "circle.fill")
                .foregroundStyle(.red)
        case .onlyInA:
            Image(systemName: "arrow.left.circle.fill")
                .foregroundStyle(.orange)
        case .onlyInB:
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var trailingLabel: some View {
        switch entry.status {
        case .same: EmptyView()
        case .differ(let n):
            Text("\(n)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.red)
        case .onlyInA:
            Text("only A")
                .font(.caption)
                .foregroundStyle(.orange)
        case .onlyInB:
            Text("only B")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
