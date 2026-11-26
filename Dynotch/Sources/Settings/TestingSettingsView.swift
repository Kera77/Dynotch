import AppKit
import SwiftUI

/// Settings › Testing: the running test build's list, Works / Broken and a report (spec TL-2, TL-3).
struct TestingSettingsView: View {
    @State private var store: TestPlanStore?
    @State private var copied: String?

    var body: some View {
        Form {
            if let store {
                Section {
                    HStack {
                        Text("\(store.checked) of \(store.items.count) checked")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(copied == "all" ? "Copied" : "Copy report") { copy(store.report(), key: "all") }
                    }
                } header: {
                    Text("Testing Wingmate \(store.version)")
                } footer: {
                    Text("Copy report puts every item on the clipboard, with the note and the last 40 lines of the log "
                        + "for each broken one. Paste it to Claude.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(TestPlan.groups(store.items), id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.items) { item in
                            TestPlanRow(store: store, item: item, copied: copied == item.id) {
                                copy(store.report(only: item), key: item.id)
                            }
                        }
                    }
                }
            } else {
                Text("This version has no test list.").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if store == nil, let items = TestPlan.current {
                store = TestPlanStore(version: AppInfo.version, items: items)
            }
        }
    }

    private func copy(_ text: String, key: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = key
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copied == key { copied = nil }
        }
    }
}

private struct TestPlanRow: View {
    let store: TestPlanStore
    let item: TestPlanItem
    let copied: Bool
    let copy: () -> Void

    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(item.log).log")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Picker("", selection: Binding(get: { store.statuses[item.id] }, set: { store.set($0, for: item) })) {
                    Text("Works").tag(TestPlanStore.Status?.some(.works))
                    Text("Broken").tag(TestPlanStore.Status?.some(.broken))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if store.statuses[item.id] == .broken {
                HStack(spacing: 8) {
                    TextField("What went wrong?", text: $note)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { store.setNote(note, for: item) }
                        .onChange(of: note) { _, text in store.setNote(text, for: item) }
                    Button(copied ? "Copied" : "Copy", action: copy)
                }
            }
        }
        .padding(.vertical, 2)
        .onAppear { note = store.notes[item.id] ?? "" }
    }
}
