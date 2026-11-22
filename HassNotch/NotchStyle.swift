import SwiftUI
import AppKit
import Combine

/// How the island at the top of the screen is drawn.
enum NotchStyle: String, CaseIterable, Identifiable {
    /// Attached to the top edge, over the physical notch of newer MacBooks.
    case notch
    /// A black pill as tall as the menu bar, for screens without a notch.
    case island

    var id: Self { self }

    var title: String {
        switch self {
        case .notch: L("Notch clasic")
        case .island: "Dynamic Island"
        }
    }

    var details: String {
        switch self {
        case .notch:
            L("Se lipește de marginea de sus a ecranului, peste notch-ul fizic. Arată natural pe MacBook Air 13″ (M2, 2022) și mai noi, MacBook Air 15″ (2023 și mai noi), MacBook Pro 14″ și 16″ (2021, M1 Pro/Max) și mai noi.")
        case .island:
            L("O bulină neagră cât bara de meniu, care se extinde când treci cu mouse-ul peste ea. Potrivită pentru Mac mini, Mac Studio, iMac, monitoare externe și MacBook-uri fără notch.")
        }
    }
}

/// How the digits change when a value changes.
enum DigitAnimation: String, CaseIterable, Identifiable {
    case rolling
    case simple

    var id: Self { self }

    var title: String {
        switch self {
        case .rolling: L("Rolă (pompă de benzină)")
        case .simple: L("Simplă")
        }
    }
}

/// App settings, persisted between launches.
@MainActor
final class NotchSettings: ObservableObject {
    static let shared = NotchSettings()

    @Published var style: NotchStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: "notchStyle") }
    }

    // MARK: Dock

    /// Dock icon; by default the app lives only in the menu bar.
    @Published var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            Self.applyDockPolicy(showInDock)
        }
    }

    /// .accessory = menu bar only; .regular = also in the Dock (and ⌘-Tab).
    static func applyDockPolicy(_ inDock: Bool) {
        NSApp.setActivationPolicy(inDock ? .regular : .accessory)
        // Without a Dock icon, open windows (e.g. Settings) must be brought to the front explicitly.
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Language

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            Localization.current = language
            HomeAssistantManager.shared.relocalizeStatuses()
        }
    }

    // MARK: Position (Dynamic Island only)

    /// Horizontal offset from the center of the screen, in points (0 = centered).
    @Published var islandOffsetX: Double {
        didSet { UserDefaults.standard.set(islandOffsetX, forKey: "islandOffsetX") }
    }
    /// Distance from the top edge of the screen, in points (0 = in the menu bar).
    @Published var islandOffsetY: Double {
        didSet { UserDefaults.standard.set(islandOffsetY, forKey: "islandOffsetY") }
    }
    /// The chosen display (CGDirectDisplayID); 0 = the main display (the one with the menu bar).
    @Published var islandScreenID: Int {
        didSet {
            UserDefaults.standard.set(islandScreenID, forKey: "islandScreenID")
            // Remember the name too: an external display's ID may change after a restart.
            let name = NSScreen.screens.first { $0.displayID == islandScreenID }?.localizedName
            if islandScreenID == 0 || name != nil {
                UserDefaults.standard.set(islandScreenID == 0 ? nil : name, forKey: "islandScreenName")
            }
        }
    }

    /// The display the notch / island lives on, regardless of which screen you're on when the app starts.
    /// If the chosen display isn't connected, the main display (the one with the menu bar) is used.
    var islandScreen: NSScreen? {
        let screens = NSScreen.screens
        if islandScreenID != 0 {
            if let byID = screens.first(where: { $0.displayID == islandScreenID }) { return byID }
            if let name = UserDefaults.standard.string(forKey: "islandScreenName"),
               let byName = screens.first(where: { $0.localizedName == name }) { return byName }
        }
        return screens.first ?? NSScreen.main
    }

    /// A short trackpad haptic when the island opens.
    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }
    /// Haptic strength: 0 subtle · 1 medium · 2 strong · 3 very strong.
    @Published var hapticStrength: Int {
        didSet { UserDefaults.standard.set(hapticStrength, forKey: "hapticStrength") }
    }

    // MARK: Notifications

    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            HomeAssistantManager.shared.startLive() // subscribe / unsubscribe from notifications
        }
    }
    /// Minimum number of seconds a notification stays on the island.
    @Published var notificationDuration: Double {
        didSet { UserDefaults.standard.set(notificationDuration, forKey: "notificationDuration") }
    }
    /// A discreet sound when a notification arrives ("" = no sound).
    @Published var notificationSound: String {
        didSet { UserDefaults.standard.set(notificationSound, forKey: "notificationSound") }
    }
    /// The island also grows vertically for a few seconds, to catch the eye.
    @Published var notificationAttention: Bool {
        didSet { UserDefaults.standard.set(notificationAttention, forKey: "notificationAttention") }
    }
    /// System sounds suitable for a discreet notification.
    static let notificationSounds = ["Pop", "Tink", "Glass", "Purr", "Ping", "Bottle", "Morse", "Hero"]

    /// Plays the chosen sound at a reduced volume.
    func playNotificationSound(_ name: String? = nil) {
        let soundName = name ?? notificationSound
        guard !soundName.isEmpty, let sound = NSSound(named: NSSound.Name(soundName)) else { return }
        sound.volume = 0.45
        sound.play()
    }

    /// The notify.* services seen so far (e.g. "mobile_app_my_iphone").
    @Published var knownNotifyServices: [String] {
        didSet { UserDefaults.standard.set(knownNotifyServices, forKey: "knownNotifyServices") }
    }
    /// The user's choice per service; without a choice only mobile_app_* are mirrored.
    @Published var mirroredOverrides: [String: Bool] {
        didSet { UserDefaults.standard.set(mirroredOverrides, forKey: "mirroredNotifyServices") }
    }

    func isServiceMirrored(_ service: String) -> Bool {
        mirroredOverrides[service] ?? service.hasPrefix("mobile_app_")
    }

    @Published var digitAnimation: DigitAnimation {
        didSet { UserDefaults.standard.set(digitAnimation.rawValue, forKey: "digitAnimation") }
    }

    /// The main screen has a physical notch (only notched MacBooks report a top safe area).
    static var screenHasNotch: Bool { (NSScreen.main?.safeAreaInsets.top ?? 0) > 0 }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "notchStyle"),
           let saved = NotchStyle(rawValue: raw) {
            style = saved
        } else {
            // First launch: pick the style that suits the screen.
            style = Self.screenHasNotch ? .notch : .island
        }
        hapticsEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
        hapticStrength = UserDefaults.standard.object(forKey: "hapticStrength") as? Int ?? 2
        language = Localization.current
        showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? false
        islandOffsetX = UserDefaults.standard.double(forKey: "islandOffsetX")
        islandOffsetY = UserDefaults.standard.double(forKey: "islandOffsetY")
        islandScreenID = UserDefaults.standard.integer(forKey: "islandScreenID")
        notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        notificationDuration = UserDefaults.standard.object(forKey: "notificationDuration") as? Double ?? 10
        notificationSound = UserDefaults.standard.string(forKey: "notificationSound") ?? "Pop"
        notificationAttention = UserDefaults.standard.object(forKey: "notificationAttention") as? Bool ?? true
        knownNotifyServices = UserDefaults.standard.stringArray(forKey: "knownNotifyServices") ?? []
        mirroredOverrides = UserDefaults.standard.dictionary(forKey: "mirroredNotifyServices") as? [String: Bool] ?? [:]
        digitAnimation = UserDefaults.standard.string(forKey: "digitAnimation")
            .flatMap(DigitAnimation.init(rawValue:)) ?? .rolling
    }
}

struct NotchStyleSettingsView: View {
    @ObservedObject private var settings = NotchSettings.shared
    @State private var hapticTestTick = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L("Tip notch")).font(.title2.bold())
            Text(L("Alege cum arată insula din partea de sus a ecranului. Schimbarea se aplică imediat."))
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 16) {
                ForEach(NotchStyle.allCases) { style in
                    NotchStyleCard(style: style, selected: settings.style == style) {
                        settings.style = style
                    }
                }
            }
            Toggle(isOn: $settings.hapticsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Vibrație în trackpad la deschiderea insulei"))
                    Text(L("Merge cu trackpadurile Force Touch (MacBook, Magic Trackpad). Cu mouse-ul nu se simte nimic."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Picker(L("Intensitate"), selection: $settings.hapticStrength) {
                Text(L("Fină")).tag(0)
                Text(L("Medie")).tag(1)
                Text(L("Puternică")).tag(2)
                Text(L("Foarte puternică")).tag(3)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 440)
            .disabled(!settings.hapticsEnabled)
            .onChange(of: settings.hapticStrength) { Haptics.tap() }
            HStack {
                // The haptic plays on press (the finger is still on the trackpad), like PowerPoint while dragging an image.
                Text(L("Testează vibrația"))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.6, perform: {}, onPressingChanged: { pressing in
                        if pressing { Haptics.tap() }
                    })
                Text(L("Ține apăsat pe buton: vibrația vine cât timp degetul apasă trackpadul."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Picker(L("Unde apare aplicația"), selection: $settings.showInDock) {
                    Text(L("Doar în bara de meniu")).tag(false)
                    Text(L("În bara de meniu și în Dock")).tag(true)
                }
                .pickerStyle(.radioGroup)
                Text(L("Fără iconiță în Dock: aplicația se deschide din iconița din bara de meniu sau din rotița de pe insulă."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label(NotchSettings.screenHasNotch
                  ? L("Ecranul principal are notch fizic: Notch clasic arată cel mai natural.")
                  : L("Ecranul principal nu are notch fizic: Dynamic Island arată cel mai natural."),
                  systemImage: "display")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NotchStyleCard: View {
    let style: NotchStyle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                preview
                HStack {
                    Text(style.title).font(.headline)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                }
                Text(style.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    /// Thumbnail: a "desktop" with the menu bar and the island shape.
    private var preview: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [.blue.opacity(0.55), .purple.opacity(0.45)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle().fill(.white.opacity(0.55)).frame(height: 12)
            switch style {
            case .notch:
                UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6, style: .continuous)
                    .fill(.black)
                    .frame(width: 58, height: 16)
            case .island:
                Capsule().fill(.black)
                    .frame(width: 40, height: 10)
                    .padding(.top, 1)
            }
        }
        .frame(height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
