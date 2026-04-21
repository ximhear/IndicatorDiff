import SwiftUI
import UniformTypeIdentifiers

struct FileSlotButton: View {
    @Environment(DiffStore.self) private var store
    let slot: FileSlotID
    let state: FileSlotState
    @State private var presentImporter = false
    @State private var isTargeted = false

    private static let parquetType: UTType = UTType(filenameExtension: "parquet") ?? .data

    var body: some View {
        Button(action: { presentImporter = true }) {
            HStack(spacing: 8) {
                label
                content
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minWidth: 220)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isTargeted ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                        lineWidth: isTargeted ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .fileImporter(
            isPresented: $presentImporter,
            allowedContentTypes: [Self.parquetType, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    store.setFile(url, slot: slot)
                }
            case .failure:
                break
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    store.setFile(url, slot: slot)
                }
            }
            return true
        }
        .contextMenu {
            if let path = state.url?.path {
                Button("Finder에서 보기") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                }
                Button("경로 복사") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                }
                Divider()
            }
            Button("파일 지우기", role: .destructive) {
                store.clearFile(slot: slot)
            }
            .disabled({
                if case .idle = state { return true }
                return false
            }())
        }
        .help(state.url?.path ?? "파일 선택")
    }

    private var label: some View {
        Text(slot == .a ? "A" : "B")
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(slot == .a ? Color.blue : Color.purple)
            )
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            Text("파일 선택…")
                .foregroundStyle(.secondary)
        case .loading(let url):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        case .loaded(let dataset):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text(dataset.sourceURL.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.callout)
                    Text("\(dataset.rowCount) rows · \(dataset.columnNames.count) cols · date: \(dataset.dateColumn)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        case .failed(let url, _):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}
