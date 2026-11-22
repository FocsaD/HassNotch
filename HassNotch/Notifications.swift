import SwiftUI

/// A notification mirrored from Home Assistant (a notify.* call — like those sent to a phone).
struct NotchNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let service: String
    let date = Date()

    /// The text shown on the island: "Title: message" or just the message.
    var text: String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanTitle.isEmpty ? message : "\(cleanTitle): \(message)"
    }
}

/// Text that scrolls continuously (like a ticker) when it doesn't fit, so it reads left
/// to right. If it fits, it stays centered and still.
struct MarqueeText: View {
    let text: String
    let font: Font
    let width: CGFloat
    /// Scrolling speed, in points per second.
    var speed: CGFloat = 45

    @State private var textWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private let gap: CGFloat = 48
    private var scrolls: Bool { textWidth > width }

    var body: some View {
        HStack(spacing: gap) {
            label
            if scrolls { label }
        }
        .fixedSize()
        .offset(x: offset)
        .frame(width: width, alignment: scrolls ? .leading : .center)
        .clipped()
        // The edges fade, so the text enters and leaves smoothly.
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0),
                                   .init(color: .black, location: scrolls ? 0.06 : 0),
                                   .init(color: .black, location: scrolls ? 0.94 : 1),
                                   .init(color: .clear, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
        }
        .onChange(of: textWidth) { restart() }
        .onChange(of: text) { restart() }
    }

    private var label: some View {
        Text(text)
            .font(font)
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
    }

    private func restart() {
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { offset = 0 }
        guard scrolls else { return }
        let distance = textWidth + gap
        withAnimation(.linear(duration: distance / speed).delay(1).repeatForever(autoreverses: false)) {
            offset = -distance
        }
    }
}

/// The "Notifications" category in Settings.
struct NotificationSettingsView: View {
    @ObservedObject private var settings = NotchSettings.shared
    @ObservedObject private var manager = HomeAssistantManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L("Notificări")).font(.title2.bold())
            Text(L("Orice notificare trimisă din Home Assistant spre telefon (notify.mobile_app_…) apare și pe insulă: Dynamic Island se lățește de două ori, notch-ul crește în jos, iar textul lung se derulează."))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(L("Afișează notificările din Home Assistant pe insulă"), isOn: $settings.notificationsEnabled)

            HStack {
                Text(L("Durată minimă pe ecran"))
                Slider(value: $settings.notificationDuration, in: 5...30, step: 1).frame(width: 200)
                Text("\(Int(settings.notificationDuration)) s").monospacedDigit().frame(width: 36, alignment: .leading)
            }
            .disabled(!settings.notificationsEnabled)
            Text(L("Textul lung rămâne cât să se poată derula o dată complet, chiar dacă durează mai mult."))
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Text(L("Sunet"))
                Picker(L("Sunet"), selection: $settings.notificationSound) {
                    Text(L("Fără sunet")).tag("")
                    ForEach(NotchSettings.notificationSounds, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 160)
                Button {
                    settings.playNotificationSound()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .help(L("Ascultă sunetul"))
                .disabled(settings.notificationSound.isEmpty)
            }
            .disabled(!settings.notificationsEnabled)

            Toggle(L("Atrage atenția: insula crește și pe verticală ~3,5 s, apoi revine"), isOn: $settings.notificationAttention)
                .disabled(!settings.notificationsEnabled)

            GroupBox(L("Pentru ce dispozitive")) {
                VStack(alignment: .leading, spacing: 6) {
                    if settings.knownNotifyServices.isEmpty {
                        Text(L("Încă n-a sosit nicio notificare. Lista se completează singură la prima notificare trimisă din HA; implicit se preiau toate cele spre aplicația mobilă (mobile_app_…)."))
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(settings.knownNotifyServices, id: \.self) { service in
                        Toggle("notify.\(service)", isOn: Binding(
                            get: { settings.isServiceMirrored(service) },
                            set: { settings.mirroredOverrides[service] = $0 }))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
            .disabled(!settings.notificationsEnabled)

            HStack {
                Button(L("Trimite o notificare de test")) { manager.sendTestNotification() }
                if !manager.notificationsStatus.isEmpty {
                    Text(manager.notificationsStatus).font(.caption).foregroundStyle(.secondary)
                }
            }

            if !manager.recentNotifications.isEmpty {
                GroupBox(L("Ultimele notificări")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(manager.recentNotifications) { notification in
                            HStack(alignment: .firstTextBaseline) {
                                Text(notification.date.formatted(date: .omitted, time: .shortened))
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                Text(notification.text).lineLimit(2)
                                Spacer()
                                Text(notification.service).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
