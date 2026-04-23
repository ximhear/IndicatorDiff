import SwiftUI

struct ViewerModeView: View {
    @Environment(DiffStore.self) private var store

    var body: some View {
        if store.viewerFolderSlot.url == nil {
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .imageScale(.large)
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("폴더를 선택하세요")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(".parquet / .csv 파일을 찾아서 한 개씩 열어볼 수 있습니다.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HSplitView {
                ViewerFileListView()
                    .frame(minWidth: 260, idealWidth: 320)
                ViewerTableView()
                    .frame(minWidth: 600)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
