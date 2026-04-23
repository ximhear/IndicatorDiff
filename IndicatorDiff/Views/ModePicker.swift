import SwiftUI

struct ModePicker: View {
    @Environment(DiffStore.self) private var store

    var body: some View {
        Picker("", selection: Binding(
            get: { store.mode },
            set: { newMode in
                guard newMode != store.mode else { return }
                store.mode = newMode
                store.result = nil
                store.selectedRowID = nil
                store.selectedColumn = nil
            }
        )) {
            Text("Files").tag(AppMode.files)
            Text("Folders").tag(AppMode.folders)
            Text("View").tag(AppMode.viewer)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 220)
    }
}
