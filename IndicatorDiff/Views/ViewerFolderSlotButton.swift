import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ViewerFolderSlotButton: View {
    @Environment(DiffStore.self) private var store
    let state: FolderSlotState
    @State private var presentImporter = false
    @State private var isTargeted = false

    var body: some View {
        Button(action: { presentImporter = true }) {
            HStack(spacing: 8) {
                label
                content
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minWidth: 260)
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
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    store.setViewerFolder(url)
                }
            case .failure:
                break
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return }
                Task { @MainActor in
                    store.setViewerFolder(url)
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
            Button("폴더 지우기", role: .destructive) {
                store.clearViewerFolder()
            }
            .disabled({
                if case .idle = state { return true }
                return false
            }())
        }
        .help(state.url?.path ?? "폴더 선택")
    }

    private var label: some View {
        Image(systemName: "folder.fill")
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.teal))
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            Text("폴더 선택…")
                .foregroundStyle(.secondary)
        case .scanning(let url):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        case .scanned(let url, let count):
            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.callout)
                Text("\(count) files")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
