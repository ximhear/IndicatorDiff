import AppKit
import SwiftUI

struct PathStatusBar: View {
    @Environment(DiffStore.self) private var store

    var body: some View {
        HStack(spacing: 10) {
            switch store.mode {
            case .files:
                PathSlotRow(label: "A", color: .blue, url: store.slotA.url)
                Divider().frame(height: 14)
                PathSlotRow(label: "B", color: .purple, url: store.slotB.url)

            case .folders:
                PathSlotRow(label: "A", color: .blue, url: store.folderSlotA.url)
                Divider().frame(height: 14)
                PathSlotRow(label: "B", color: .purple, url: store.folderSlotB.url)

                if let pair = selectedPair {
                    Divider().frame(height: 14)
                    PathSlotRow(label: "pair A", color: .blue, url: pair.fileA)
                    Divider().frame(height: 14)
                    PathSlotRow(label: "pair B", color: .purple, url: pair.fileB)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .top)
    }

    private var selectedPair: FilePair? {
        guard let id = store.selectedPairID else { return nil }
        return store.filePairs.first(where: { $0.id == id })
    }
}

private struct PathSlotRow: View {
    let label: String
    let color: Color
    let url: URL?

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(color))
            if let url {
                Text(url.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(url.path)
                    .onTapGesture(count: 2) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .contextMenu {
                        Button("Finder에서 보기") {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        Button("경로 복사") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.path, forType: .string)
                        }
                    }
            } else {
                Text("—")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
