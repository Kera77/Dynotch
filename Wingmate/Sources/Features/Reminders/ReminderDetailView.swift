import SwiftUI

/// A reminder's details over the module, like the Reminders app's info panel (spec R-14):
/// title, notes, link, date and time, repeat, early alert, list and priority.
struct ReminderDetailView: View {
    var store: RemindersStore
    let id: String
    @State private var details: ReminderDetails?
    @State private var original: ReminderDetails?

    var body: some View {
        VStack(spacing: 0) {
            header
            if let binding = Binding($details) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 10) {
                            texts(binding)
                            dateSection(binding) { revealMonth(proxy) }
                            optionsSection(binding)
                        }
                        .padding(12)
                    }
                    .scrollIndicators(.never)
                }
            } else {
                Text("This reminder is gone.").foregroundStyle(Color.white.level(0.6)).frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: AppleStyle.corner(12), style: .continuous).fill(Color(white: 0.11)))
        .overlay(RoundedRectangle(cornerRadius: AppleStyle.corner(12), style: .continuous).stroke(Color.white.level(0.1)))
        .onAppear {
            details = store.details(for: id)
            original = details
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle").foregroundStyle(Theme.blue)
            Text("Details").font(.notch(size: 13, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            Button("Cancel") { close() }
                .buttonStyle(.notch)
                .foregroundStyle(Color.white.level(0.7))
            Button("Done") { saveAndClose() }
                .buttonStyle(.notch)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.blue)
                .keyboardShortcut(.defaultAction)
        }
        .font(.notch(size: 12))
        .padding(.horizontal, 12)
        .frame(height: 34)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.level(0.08)).frame(height: 1) }
    }

    private func texts(_ details: Binding<ReminderDetails>) -> some View {
        DetailGroup {
            TextField("Title", text: details.title).font(.notch(size: 13, weight: .semibold))
            Divider().overlay(Color.white.level(0.08))
            TextField("Notes", text: details.notes, axis: .vertical).lineLimit(1...4)
            Divider().overlay(Color.white.level(0.08))
            TextField("URL", text: details.url)
        }
        .textFieldStyle(.plain)
        .font(.notch(size: 12))
    }

    /// The opened month scrolls fully into view, no scrolling by hand (spec R-25).
    private func revealMonth(_ proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(Motion.quick) { proxy.scrollTo(ReminderDayPicker.monthID, anchor: .bottom) }
        }
    }

    private func dateSection(_ details: Binding<ReminderDetails>, onShowMonth: @escaping () -> Void) -> some View {
        DetailGroup {
            DetailRow(symbol: "calendar", title: "Date", detail: nil) {
                Toggle("", isOn: details.hasDate).labelsHidden().toggleStyle(.switch).controlSize(.mini)
            }
            // Inside the notch, never a system pop-up (spec R-24).
            if details.wrappedValue.hasDate {
                ReminderDayPicker(due: details.due, onShowMonth: onShowMonth).padding(.leading, 28)
            }
            Divider().overlay(Color.white.level(0.08))
            DetailRow(symbol: "clock", title: "Time", detail: nil) {
                Toggle("", isOn: Binding(
                    get: { details.wrappedValue.hasTime },
                    set: { isOn in
                        details.wrappedValue.hasTime = isOn
                        // A time needs a day, as in the Reminders app.
                        if isOn { details.wrappedValue.hasDate = true }
                    }
                ))
                .labelsHidden().toggleStyle(.switch).controlSize(.mini)
            }
            if details.wrappedValue.hasTime {
                ReminderTimePicker(due: details.due).padding(.leading, 28)
            }
        }
    }

    private func optionsSection(_ details: Binding<ReminderDetails>) -> some View {
        let value = details.wrappedValue
        let repeats = ReminderRepeat.allCases.filter { $0 != .custom || value.repeats == .custom }
        // Soft capsules with the usual menus instead of system pop-up buttons (spec R-24).
        return DetailGroup {
            DetailRow(symbol: "repeat", title: "Repeat", detail: nil) {
                ReminderMenu(
                    title: value.repeats.title, selection: details.repeats,
                    options: repeats.map { ($0.title, $0) }, isEnabled: value.hasDate
                )
            }
            DetailRow(symbol: "bell", title: "Early Reminder", detail: nil) {
                ReminderMenu(
                    title: value.early.title, selection: details.early,
                    options: EarlyReminder.allCases.map { ($0.title, $0) }, isEnabled: value.hasTime
                )
            }
            DetailRow(symbol: "list.bullet", title: "List", detail: nil) {
                ReminderMenu(
                    title: store.lists.first { $0.id == value.listID }?.title ?? "List", selection: details.listID,
                    options: store.lists.map { ($0.title, $0.id) }
                )
            }
            DetailRow(symbol: "exclamationmark", title: "Priority", detail: nil) {
                ReminderMenu(
                    title: ReminderDetails.priorities.first { $0.value == value.priority }?.title ?? "None",
                    selection: details.priority, options: ReminderDetails.priorities.map { ($0.title, $0.value) }
                )
            }
            Button("Flags, tags, places and images: open in Reminders") { store.openRemindersApp() }
                .buttonStyle(.notch)
                .font(.notch(size: 10))
                .foregroundStyle(Color.white.level(0.45))
        }
    }

    private func close() {
        withAnimation(Motion.quick) { store.editingID = nil }
    }

    private func saveAndClose() {
        if let details, let original, details != original { store.save(details, original: original, id: id) }
        close()
    }
}

/// A rounded group of rows, like the Reminders app's sections.
private struct DetailGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: AppleStyle.corner(10), style: .continuous).fill(Color.white.level(0.06)))
    }
}

/// An icon, a title (and a grey line under it), and a control at the right.
private struct DetailRow<Control: View>: View {
    let symbol: String
    let title: String
    let detail: String?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.notch(size: 13))
                .foregroundStyle(Color.white.level(0.6))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.notch(size: 12, weight: .medium)).foregroundStyle(.white)
                if let detail {
                    Text(detail).font(.notch(size: 10)).foregroundStyle(Theme.blue)
                }
            }
            Spacer(minLength: 8)
            control
        }
        .controlSize(.small)
    }
}
