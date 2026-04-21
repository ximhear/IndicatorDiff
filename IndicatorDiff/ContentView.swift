import SwiftUI

struct ContentView: View {
    @Environment(DiffStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            ToolbarBar()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Divider()

            body(for: store.mode)

            if let msg = store.slotA.failureMessage {
                ErrorBanner(slot: "A", message: msg)
            }
            if let msg = store.slotB.failureMessage {
                ErrorBanner(slot: "B", message: msg)
            }
            if let msg = store.folderSlotA.failureMessage {
                ErrorBanner(slot: "Folder A", message: msg)
            }
            if let msg = store.folderSlotB.failureMessage {
                ErrorBanner(slot: "Folder B", message: msg)
            }

            PathStatusBar()
        }
        .frame(minWidth: 1020, minHeight: 620)
    }

    @ViewBuilder
    private func body(for mode: AppMode) -> some View {
        switch mode {
        case .files:
            if store.slotA.dataset != nil, store.slotB.dataset != nil {
                threePane
            } else {
                EmptyStateView(context: .files)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .folders:
            if store.folderSlotA.url != nil, store.folderSlotB.url != nil {
                HSplitView {
                    FilePairListView()
                        .frame(minWidth: 260, idealWidth: 300)
                    detailArea
                        .frame(minWidth: 600)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyStateView(context: .folders)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var threePane: some View {
        HSplitView {
            DateListView()
                .frame(minWidth: 220, idealWidth: 260)
            ColumnSummaryView()
                .frame(minWidth: 280, idealWidth: 360)
            CellDetailView()
                .frame(minWidth: 280, idealWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var detailArea: some View {
        if store.selectedPairID == nil {
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .imageScale(.large)
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("왼쪽 목록에서 파일을 고르세요")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.result != nil {
            threePane
        } else if store.isComputingDiff {
            VStack(spacing: 8) {
                ProgressView()
                Text("비교 중…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            pairOnlySideMessage
        }
    }

    @ViewBuilder
    private var pairOnlySideMessage: some View {
        if let id = store.selectedPairID,
           let pair = store.filePairs.first(where: { $0.id == id }) {
            switch pair.status {
            case .onlyInA:
                sideOnlyMessage(text: "이 파일은 A 폴더에만 있습니다.", subtitle: pair.displayNameA)
            case .onlyInB:
                sideOnlyMessage(text: "이 파일은 B 폴더에만 있습니다.", subtitle: pair.displayNameB)
            case .error(let msg):
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.yellow)
                    Text(msg).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                Color.clear
            }
        } else {
            Color.clear
        }
    }

    private func sideOnlyMessage(text: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "arrowshape.turn.up.backward.circle")
                .imageScale(.large)
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text(text)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.callout.monospaced())
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum EmptyStateContext { case files, folders }

private struct EmptyStateView: View {
    @Environment(DiffStore.self) private var store
    let context: EmptyStateContext

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: context == .files ? "square.on.square.dashed" : "folder.badge.plus")
                .imageScale(.large)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(promptText)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(helperText)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var promptText: String {
        switch context {
        case .files:
            let a = store.slotA.dataset != nil
            let b = store.slotB.dataset != nil
            if !a && !b { return "파일 A와 B를 선택하세요" }
            if !a { return "파일 A를 선택하세요" }
            return "파일 B를 선택하세요"
        case .folders:
            let a = store.folderSlotA.url != nil
            let b = store.folderSlotB.url != nil
            if !a && !b { return "폴더 A와 B를 선택하세요" }
            if !a { return "폴더 A를 선택하세요" }
            return "폴더 B를 선택하세요"
        }
    }

    private var helperText: String {
        switch context {
        case .files:
            return "두 parquet/csv 파일을 고르면 날짜·컬럼별 차이를 보여드립니다."
        case .folders:
            return "두 폴더에서 이름이 같은 parquet/csv 파일을 짝지어 비교합니다."
        }
    }
}

private struct ErrorBanner: View {
    let slot: String
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("\(slot): \(message)")
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.12))
    }
}

#Preview {
    ContentView()
        .environment(DiffStore())
        .environment(ComparisonHistory())
}
