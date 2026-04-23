import AppKit
import SwiftUI

struct ViewerFileListView: View {
    @Environment(DiffStore.self) private var store

    var body: some View {
        @Bindable var bindable = store
        let files = store.viewerFilteredFiles

        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()
            if files.isEmpty {
                Spacer()
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List(files, id: \.self, selection: Binding(
                    get: { store.viewerLoadState.url },
                    set: { newValue in
                        if let newValue { store.selectViewerFile(newValue) }
                    }
                )) { url in
                    ViewerFileRow(url: url)
                        .tag(url)
                }
                .listStyle(.inset)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Files")
                .font(.headline)
            Spacer()
            if store.viewerFolderSlot.url != nil {
                Text("\(store.viewerFilteredFiles.count)/\(store.viewerFiles.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchBar: some View {
        @Bindable var bindable = store
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("파일 이름 검색…", text: $bindable.viewerSearchQuery)
                .textFieldStyle(.plain)
                .font(.callout)
            if !store.viewerSearchQuery.isEmpty {
                Button {
                    store.viewerSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var emptyText: String {
        if store.viewerFolderSlot.url == nil {
            return "폴더를 먼저 선택하세요"
        }
        if !store.viewerSearchQuery.isEmpty {
            return "'\(store.viewerSearchQuery)'에 해당하는 파일 없음"
        }
        return ".parquet / .csv 파일이 없습니다"
    }
}

private struct ViewerFileRow: View {
    let url: URL

    var body: some View {
        HStack(spacing: 8) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            Text(source?.displayName ?? "—")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .help(url.path)
        .contextMenu {
            Button("Finder에서 보기") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Button("경로 복사") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
            }
        }
    }

    private var source: TableSource? { TableSource.infer(from: url) }

    @ViewBuilder
    private var icon: some View {
        switch source {
        case .parquet:
            Image(systemName: "doc.fill")
                .foregroundStyle(.blue)
        case .csv:
            Image(systemName: "doc.plaintext.fill")
                .foregroundStyle(.green)
        default:
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
        }
    }
}
