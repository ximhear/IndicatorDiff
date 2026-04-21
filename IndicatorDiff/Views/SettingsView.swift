import SwiftUI

struct SettingsView: View {
    @Environment(DiffStore.self) private var store

    var body: some View {
        @Bindable var bindable = store

        Form {
            Section("Tolerance (숫자 비교 허용오차)") {
                LabeledContent("absolute") {
                    TextField("abs", value: $bindable.toleranceAbs, format: .number.precision(.significantDigits(1...6)))
                        .frame(width: 140)
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("relative") {
                    TextField("rel", value: $bindable.toleranceRel, format: .number.precision(.significantDigits(1...6)))
                        .frame(width: 140)
                        .font(.system(.body, design: .monospaced))
                }
                Text("판정식: |a-b| ≤ max(abs, rel × max(|a|,|b|))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("현재 설정 반영") {
                    store.applyToleranceChange()
                }
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
