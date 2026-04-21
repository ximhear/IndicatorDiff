import SwiftUI

struct HistoryMenu: View {
    @Environment(DiffStore.self) private var store
    @Environment(ComparisonHistory.self) private var history
    @State private var presented = false

    var body: some View {
        Button {
            presented.toggle()
        } label: {
            Image(systemName: "clock.arrow.circlepath")
        }
        .help("비교 기록")
        .popover(isPresented: $presented, arrowEdge: .bottom) {
            HistoryPopover(onPick: { entry in
                store.restore(entry)
                presented = false
            })
            .environment(history)
            .frame(width: 460, height: 360)
        }
    }
}

private struct HistoryPopover: View {
    @Environment(ComparisonHistory.self) private var history
    let onPick: (HistoryEntry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("비교 기록")
                    .font(.headline)
                Spacer()
                Text("\(history.entries.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()

            if history.entries.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .imageScale(.large)
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("아직 기록이 없습니다")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                Spacer()
            } else {
                List {
                    ForEach(history.entries) { entry in
                        HistoryRow(entry: entry, onPick: { onPick(entry) })
                    }
                    .onDelete { offsets in
                        for idx in offsets {
                            let id = history.entries[idx].id
                            history.remove(id: id)
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()
            HStack {
                if hasUnrestorable {
                    Button("복원 불가 항목 지우기") {
                        for entry in history.entries where !(entry.slotA.hasBookmark && entry.slotB.hasBookmark) {
                            history.remove(id: entry.id)
                        }
                    }
                    .controlSize(.small)
                }
                Spacer()
                Button("모두 지우기", role: .destructive) {
                    history.clear()
                }
                .disabled(history.entries.isEmpty)
                .controlSize(.small)
            }
            .padding(8)
        }
    }

    private var hasUnrestorable: Bool {
        history.entries.contains { !($0.slotA.hasBookmark && $0.slotB.hasBookmark) }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let onPick: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var restorable: Bool {
        entry.slotA.hasBookmark && entry.slotB.hasBookmark
    }

    var body: some View {
        Button(action: { if restorable { onPick() } }) {
            HStack(spacing: 10) {
                modeBadge
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "a.circle.fill").foregroundStyle(.blue)
                        Text(entry.slotA.path)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(entry.slotA.path)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "b.circle.fill").foregroundStyle(.purple)
                        Text(entry.slotB.path)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(entry.slotB.path)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if !restorable {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .imageScale(.small)
                                .foregroundStyle(.yellow)
                            Text("복원 불가")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                        .help("파일 권한 북마크가 없어 복원할 수 없습니다 (구 버전 기록). 이 항목을 지우고 파일을 다시 선택해 주세요.")
                    }
                    Text(Self.relativeFormatter.localizedString(for: entry.timestamp, relativeTo: Date()))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .opacity(restorable ? 1.0 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!restorable)
    }

    private var modeBadge: some View {
        let text: String = entry.mode == .files ? "Files" : "Folders"
        let color: Color = entry.mode == .files ? .blue : .indigo
        let icon: String = entry.mode == .files ? "doc.on.doc" : "folder.fill"
        return HStack(spacing: 3) {
            Image(systemName: icon)
                .imageScale(.small)
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(color)
        .background(color.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 0.5))
    }
}
