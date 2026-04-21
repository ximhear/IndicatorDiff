import SwiftUI

struct CellDetailView: View {
    @Environment(DiffStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack {
            Text("Cell")
                .font(.headline)
            Spacer()
            if let cell = store.selectedCell {
                Text(cell.column)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if let cell = store.selectedCell {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    valueBox(label: "A", slotColor: .blue, value: cell.a, typeLabel: cell.typeA)
                    valueBox(label: "B", slotColor: .purple, value: cell.b, typeLabel: cell.typeB)
                    deltaBox(cell: cell)
                }
                .padding(12)
            }
        } else {
            VStack {
                Spacer()
                Text("컬럼을 선택하세요")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func valueBox(label: String, slotColor: Color, value: CellValue, typeLabel: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(value.displayString)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("type: \(typeLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(slotColor))
        }
    }

    private func deltaBox(cell: CellDiff) -> some View {
        GroupBox("Δ") {
            VStack(alignment: .leading, spacing: 6) {
                Text(statusText(for: cell.status))
                    .font(.system(.body, design: .monospaced))
                if let d = cell.numericDelta {
                    if d.absolute.isFinite {
                        row(key: "abs", value: CellValue.formatDouble(d.absolute))
                    }
                    if let rel = d.relative, rel.isFinite {
                        row(key: "rel", value: CellValue.formatDouble(rel))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(key: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private func statusText(for status: CellStatus) -> String {
        switch status {
        case .same: return "same"
        case .differ: return "differ"
        case .typeMismatch: return "type mismatch"
        case .onlyInA: return "only in A"
        case .onlyInB: return "only in B"
        }
    }
}
