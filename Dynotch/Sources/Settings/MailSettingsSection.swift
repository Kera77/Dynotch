import SwiftUI

/// Settings › Notifications › Gmail: where Gmail's unread mail comes from, and the Mail accounts
/// shown (spec GM-3, GM-9, GM-11, GM-12).
struct MailSettingsSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var mail: MailService

    var body: some View {
        Section {
            Picker("Source", selection: $settings.mailSource) {
                ForEach(MailSource.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            if settings.mailSource == .appleMail {
                LabeledContent("Status") {
                    Text(MailFormat.status(mail)).foregroundStyle(mail.state == .reading ? .green : .secondary)
                }
                ForEach(mail.accounts) { account in
                    Toggle(isOn: Binding(get: { mail.isShown(account) }, set: { mail.setShown($0, for: account) })) {
                        Text(account.name + (account.isGmail ? " (Gmail)" : ""))
                    }
                }
                TextField("Gmail Primary label", text: $mail.primaryLabel, prompt: Text("Primary"))
                LabeledContent("Check every") {
                    HStack(spacing: 6) {
                        Text("\(mail.interval) s").monospacedDigit()
                        Stepper("", value: $mail.interval, in: MailService.intervalRange, step: 30).labelsHidden()
                    }
                }
                Toggle("Keep Mail running in the background", isOn: $mail.keepsMailRunning)
                LabeledContent("Mail's own alerts") {
                    Button("Open Notification Settings…", action: mail.openMailNotificationSettings)
                }
            }
        } header: {
            Text("Gmail")
        } footer: {
            Text(settings.mailSource == .appleMail
                ? "Reads the unread mail of the accounts set up in Apple Mail, only reading, never marking anything read; "
                    + "each account chosen gets a group in the Mail tab. Mail must run to fetch new mail. To keep it quiet, "
                    + "turn off its notifications and badge in System Settings. Nothing is kept on disk. "
                    + "With a Gmail filter that gives category:primary mail this label, only the Inbox mail "
                    + "that has it counts, as in Gmail's Primary tab; without the label, the whole Inbox."
                : "Sender and subject come from Gmail's notifications: mail that came without one does not show.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
