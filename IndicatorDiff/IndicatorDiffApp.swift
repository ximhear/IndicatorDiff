import SwiftUI

@main
struct IndicatorDiffApp: App {
    @State private var store: DiffStore
    @State private var history: ComparisonHistory

    init() {
        let h = ComparisonHistory()
        let s = DiffStore()
        s.history = h
        _history = State(initialValue: h)
        _store = State(initialValue: s)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(history)
        }
        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
