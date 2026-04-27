import SwiftUI

struct ViewerTableView: View {
    @Environment(DiffStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let ds = store.viewerLoadState.dataset {
                columnFilterBar(for: ds)
                Divider()
            }
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

    private func columnFilterBar(for ds: ParquetDataset) -> some View {
        @Bindable var bindable = store
        let visible = visibleColumns(for: ds)
        let truncated = visible.count < filteredColumns(for: ds).count
        return HStack(spacing: 8) {
            Image(systemName: "rectangle.split.3x1")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("컬럼 이름 검색…", text: $bindable.viewerColumnQuery)
                .textFieldStyle(.plain)
                .font(.callout)
                .frame(maxWidth: 240)
            if !store.viewerColumnQuery.isEmpty {
                Button {
                    store.viewerColumnQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Divider().frame(height: 14)
            Text("\(visible.count)/\(ds.columnNames.count) cols")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            if truncated {
                Toggle(isOn: $bindable.viewerShowAllColumns) {
                    Text("Show all")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .help("\(ds.columnNames.count)개 전부 표시 — 매우 느릴 수 있음")
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
            DataTable(dataset: ds, columns: visibleColumns(for: ds))
        }
    }

    private func filteredColumns(for ds: ParquetDataset) -> [String] {
        let q = store.viewerColumnQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return ds.columnNames }
        return ds.columnNames.filter { $0.lowercased().contains(q) }
    }

    private func visibleColumns(for ds: ParquetDataset) -> [String] {
        let filtered = filteredColumns(for: ds)
        if store.viewerShowAllColumns { return filtered }
        if filtered.count <= store.viewerColumnLimit { return filtered }
        return Array(filtered.prefix(store.viewerColumnLimit))
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

private struct DataRowID: Identifiable, Hashable {
    let id: Int
}

private struct DataTable: View {
    let dataset: ParquetDataset
    let columns: [String]

    private var rows: [DataRowID] {
        (0..<dataset.rowCount).map { DataRowID(id: $0) }
    }

    var body: some View {
        Table(rows) {
            TableColumnForEach(columns, id: \.self) { column in
                TableColumn(Text(column).font(.system(.caption, design: .monospaced).weight(.semibold))) { row in
                    cell(row: row.id, column: column)
                }
            }
        }
    }

    @ViewBuilder
    private func cell(row: Int, column: String) -> some View {
        let v = dataset.value(row: row, column: column)
        let s = v.displayString
        Text(s)
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(v.isNull ? Color.secondary : Color.primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .help(s)
    }
}
