import SwiftUI

struct ViewerTableView: View {
    @Environment(DiffStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let ds = store.viewerLoadState.dataset {
                Text(ds.sourceURL.lastPathComponent)
                    .font(.system(.headline, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(ds.sourceURL.path)
                Text("\(ds.rowCount) rows × \(ds.columnNames.count) cols")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if ds.duplicateDateCount > 0 {
                    Text("dup dates: \(ds.duplicateDateCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.yellow)
                }
            } else {
                Text("Viewer")
                    .font(.headline)
            }
            Spacer()
            Text(sourceBadge)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var sourceBadge: String {
        guard let url = store.viewerLoadState.url else { return "" }
        return TableSource.infer(from: url)?.displayName ?? ""
    }

    @ViewBuilder
    private var content: some View {
        switch store.viewerLoadState {
        case .idle:
            placeholder(
                icon: "tablecells",
                title: "파일을 선택하면 여기에 내용을 표시합니다",
                subtitle: nil
            )
        case .loading(let url):
            VStack(spacing: 8) {
                ProgressView()
                Text(url.lastPathComponent)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(_, let message):
            placeholder(
                icon: "exclamationmark.triangle.fill",
                title: "열 수 없음",
                subtitle: message
            )
        case .loaded(let ds):
            DataTable(dataset: ds)
        }
    }

    private func placeholder(icon: String, title: String, subtitle: String?) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .imageScale(.large)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(title)
                .foregroundStyle(.secondary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Row = a single row index. `ParquetDataset` is captured by the closures
/// so we don't materialize a dictionary per row up-front.
private struct DataRowID: Identifiable, Hashable {
    let id: Int
}

private struct DataTable: View {
    let dataset: ParquetDataset

    private var rows: [DataRowID] {
        (0..<dataset.rowCount).map { DataRowID(id: $0) }
    }

    var body: some View {
        Table(rows) {
            TableColumnForEach(dataset.columnNames, id: \.self) { column in
                TableColumn(Text(column).font(.system(.caption, design: .monospaced).weight(.semibold))) { row in
                    cell(row: row.id, column: column)
                }
            }
        }
    }

    @ViewBuilder
    private func cell(row: Int, column: String) -> some View {
        let v = dataset.value(row: row, column: column)
        Text(v.displayString)
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(v.isNull ? Color.secondary : Color.primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .help(v.displayString)
    }
}
