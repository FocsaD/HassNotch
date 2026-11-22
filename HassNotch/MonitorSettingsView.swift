import SwiftUI
import AppKit

/// The "Display" category: which screen HassNotch lives on.
struct MonitorSettingsView: View {
    @ObservedObject private var settings = NotchSettings.shared
    /// The display list refreshes when a screen is connected / disconnected.
    @State private var screens: [NSScreen] = NSScreen.screens

    private var chosenMissing: Bool {
        settings.islandScreenID != 0 && !screens.contains { $0.displayID == settings.islandScreenID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L("Monitor")).font(.title2.bold())
            Text(L("Alege monitorul pe care apare HassNotch. Rămâne mereu acolo, indiferent pe ce ecran lucrezi când pornește aplicația."))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("", selection: $settings.islandScreenID) {
                        Text(L("Monitorul principal (cel cu bara de meniu)")).tag(0)
                        ForEach(Array(screens.enumerated()), id: \.element.displayID) { index, screen in
                            Text(description(of: screen, index: index)).tag(screen.displayID)
                        }
                        if chosenMissing {
                            Text(UserDefaults.standard.string(forKey: "islandScreenName") ?? "—")
                                .tag(settings.islandScreenID)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .disabled(screens.count < 2)

                    if screens.count < 2 {
                        Label(L("Ai un singur monitor conectat, deci HassNotch apare pe el. Alegerea devine activă când conectezi încă un monitor."),
                              systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if chosenMissing {
                        Label(L("Monitorul ales nu e conectat acum."), systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(L("Dacă monitorul ales e deconectat, HassNotch trece pe monitorul principal și revine singur când îl reconectezi."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = NSScreen.screens
        }
    }

    private func description(of screen: NSScreen, index: Int) -> String {
        var parts = ["\(index + 1). \(screen.localizedName)",
                     "\(Int(screen.frame.width))×\(Int(screen.frame.height))"]
        if index == 0 { parts.append(L("principal")) }
        if screen.safeAreaInsets.top > 0 { parts.append(L("cu notch")) }
        return parts.joined(separator: " · ")
    }
}
