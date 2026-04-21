import SwiftUI

struct FilePairListView: View {
    @Environment(DiffStore.self) private var store

    var body: some View {
        @Bindable var bindable = store
        let pairs = store.filteredPairs

        VStack(spacing: 0) {
            header
            Divider()
            if pairs.isEmpty {
                Spacer()
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List(pairs, selection: Binding(
                    get: { store.selectedPairID },
                    set: { newValue in
                        if let newValue { store.selectPair(newValue) }
                    }
                )) { pair in
                    FilePairRow(pair: pair)
                        .tag(pair.id)
                }
                .listStyle(.inset)
            }

            if store.isBatchComparing {
                batchFooter
            }
        }
    }

    private var header: some View {
        @Bindable var bindable = store
        let counts = store.pairStatusCounts
        let visibleCount = store.filteredPairs.count
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Files")
                    .font(.headline)
                if counts.total > 0 {
                    Text("\(visibleCount)/\(counts.total)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if counts.total > 0 {
                    pairCountBadges(counts: counts)
                }
                Button {
                    if store.isBatchComparing {
                        store.cancelBatch()
                    } else {
                        store.compareAll()
                    }
                } label: {
                    if store.isBatchComparing {
                        Label("Stop", systemImage: "stop.fill")
                            .labelStyle(.iconOnly)
                    } else {
                        Label("Compare All", systemImage: "play.fill")
                            .labelStyle(.iconOnly)
                    }
                }
                .controlSize(.small)
                .help(store.isBatchComparing ? "Stop batch compare" : "Compare all pending pairs")
                .disabled(!store.isBatchComparing && store.filePairs.allSatisfy { $0.status != .pending })
            }
            HStack(spacing: 10) {
                Toggle(isOn: $bindable.showPairsOnlyInA) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.circle.fill")
                            .foregroundStyle(counts.onlyA == 0 ? Color.secondary : Color.orange)
                        Text("A-only")
                            .font(.caption)
                        Text("(\(counts.onlyA))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(counts.onlyA == 0)

                Toggle(isOn: $bindable.showPairsOnlyInB) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(counts.onlyB == 0 ? Color.secondary : Color.orange)
                        Text("B-only")
                            .font(.caption)
                        Text("(\(counts.onlyB))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(counts.onlyB == 0)

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func pairCountBadges(counts: DiffStore.PairStatusCounts) -> some View {
        HStack(spacing: 5) {
            if counts.differ > 0 {
                PairCountBadge(systemImage: "circle.fill", color: .red, value: counts.differ, help: "differ")
            }
            if counts.onlyA > 0 {
                PairCountBadge(systemImage: "arrow.left.circle.fill", color: .orange, value: counts.onlyA, help: "only in A")
            }
            if counts.onlyB > 0 {
                PairCountBadge(systemImage: "arrow.right.circle.fill", color: .orange, value: counts.onlyB, help: "only in B")
            }
            if counts.error > 0 {
                PairCountBadge(systemImage: "exclamationmark.triangle.fill", color: .yellow, value: counts.error, help: "error")
            }
            if counts.pending > 0 {
                PairCountBadge(systemImage: "circle.dotted", color: .secondary, value: counts.pending, help: "pending")
            }
            if counts.same > 0 {
                PairCountBadge(systemImage: "circle", color: .secondary, value: counts.same, help: "same")
            }
        }
    }

    private var batchFooter: some View {
        VStack(spacing: 4) {
            ProgressView(
                value: Double(store.batchProgress.done),
                total: Double(max(store.batchProgress.total, 1))
            )
            Text("\(store.batchProgress.done) / \(store.batchProgress.total)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08))
    }

    private var emptyText: String {
        let aOK = store.folderSlotA.url != nil
        let bOK = store.folderSlotB.url != nil
        if !aOK && !bOK { return "폴더 A와 B를 선택하세요" }
        if !aOK { return "폴더 A를 선택하세요" }
        if !bOK { return "폴더 B를 선택하세요" }
        return "대응되는 .parquet/.csv 파일이 없습니다"
    }
}

private struct FilePairRow: View {
    let pair: FilePair

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            VStack(alignment: .leading, spacing: 1) {
                Text(pair.stem)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            trailing
        }
        .help(helpText)
        .contextMenu {
            if let a = pair.fileA {
                Button("A · Finder에서 보기") {
                    NSWorkspace.shared.activateFileViewerSelecting([a])
                }
                Button("A 경로 복사") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(a.path, forType: .string)
                }
            }
            if let b = pair.fileB {
                Button("B · Finder에서 보기") {
                    NSWorkspace.shared.activateFileViewerSelecting([b])
                }
                Button("B 경로 복사") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(b.path, forType: .string)
                }
            }
        }
    }

    private var helpText: String {
        var lines: [String] = []
        if let a = pair.fileA { lines.append("A: \(a.path)") }
        if let b = pair.fileB { lines.append("B: \(b.path)") }
        return lines.joined(separator: "\n")
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch pair.status {
        case .pending:
            Image(systemName: "circle.dotted").foregroundStyle(.secondary)
        case .computing:
            ProgressView().controlSize(.mini)
        case .same:
            Image(systemName: "circle").foregroundStyle(.secondary)
        case .differ:
            Image(systemName: "circle.fill").foregroundStyle(.red)
        case .onlyInA:
            Image(systemName: "arrow.left.circle.fill").foregroundStyle(.orange)
        case .onlyInB:
            Image(systemName: "arrow.right.circle.fill").foregroundStyle(.orange)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch pair.status {
        case .differ(let cells, let rows):
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(rows) rows")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.red)
                Text("\(cells) cells")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .onlyInA:
            Text("only A").font(.caption).foregroundStyle(.orange)
        case .onlyInB:
            Text("only B").font(.caption).foregroundStyle(.orange)
        case .same:
            Text("same").font(.caption).foregroundStyle(.secondary)
        case .pending:
            Text("—").font(.caption).foregroundStyle(.secondary)
        case .computing:
            Text("…").font(.caption).foregroundStyle(.secondary)
        case .error(let msg):
            Text(msg)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 140)
        }
    }

    private var subtitle: String {
        var parts: [String] = [pair.formatLabel]
        if !pair.conflictNotes.isEmpty {
            parts.append("⚠ " + pair.conflictNotes.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }
}

private struct PairCountBadge: View {
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
