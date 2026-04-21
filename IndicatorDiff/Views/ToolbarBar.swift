import SwiftUI
import UniformTypeIdentifiers

struct ToolbarBar: View {
    @Environment(DiffStore.self) private var store

    var body: some View {
        @Bindable var bindable = store

        HStack(alignment: .center, spacing: 12) {
            ModePicker()

            HistoryMenu()

            Divider().frame(height: 28)

            switch store.mode {
            case .files:
                FileSlotButton(slot: .a, state: store.slotA)
                FileSlotButton(slot: .b, state: store.slotB)
            case .folders:
                FolderSlotButton(slot: .a, state: store.folderSlotA)
                FolderSlotButton(slot: .b, state: store.folderSlotB)
            }

            Divider().frame(height: 28)

            Picker("", selection: Binding(
                get: { store.tolerance.isStrict ? 0 : 1 },
                set: { newValue in
                    store.tolerance = newValue == 0 ? .strict : .tolerant(abs: store.toleranceAbs, rel: store.toleranceRel)
                    store.applyToleranceChange()
                }
            )) {
                Text("Strict").tag(0)
                Text("Tolerant").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
            .labelsHidden()

            Toggle("diff만 보기", isOn: $bindable.showOnlyDiffs)
                .toggleStyle(.switch)

            Spacer()

            if store.isComputingDiff {
                ProgressView()
                    .controlSize(.small)
                Text("계산 중…")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            if let result = store.result {
                summaryBadges(for: result)
            }
        }
    }

    @ViewBuilder
    private func summaryBadges(for result: DiffResult) -> some View {
        HStack(spacing: 6) {
            Badge(
                label: "diff",
                value: "\(result.diffCount)",
                color: result.diffCount == 0 ? .green : .red
            )
            if !result.onlyInA.isEmpty {
                Badge(label: "only A cols", value: "\(result.onlyInA.count)", color: .orange)
            }
            if !result.onlyInB.isEmpty {
                Badge(label: "only B cols", value: "\(result.onlyInB.count)", color: .orange)
            }
            if let a = store.slotA.dataset, a.duplicateDateCount > 0 {
                Badge(label: "dup A", value: "\(a.duplicateDateCount)", color: .yellow)
            }
            if let b = store.slotB.dataset, b.duplicateDateCount > 0 {
                Badge(label: "dup B", value: "\(b.duplicateDateCount)", color: .yellow)
            }
        }
    }
}

private struct Badge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.18), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 0.5))
    }
}
