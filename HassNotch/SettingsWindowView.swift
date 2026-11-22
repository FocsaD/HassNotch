import SwiftUI
import Combine

/// The categories in the settings window's sidebar.
enum SettingsTab: String, CaseIterable, Identifiable {
    case connection
    case display
    case notchType
    case monitor
    case notifications
    case position
    case language
    case support

    var id: Self { self }

    var title: String {
        switch self {
        case .connection: L("Conectare la Home Assistant")
        case .display: L("Informații afișate")
        case .notchType: L("Tip notch")
        case .monitor: L("Monitor")
        case .notifications: L("Notificări")
        case .position: L("Poziționare")
        case .language: L("Limbă")
        case .support: L("Buy me a beer")
        }
    }

    var icon: String {
        switch self {
        case .connection: "house.fill"
        case .display: "gauge.with.dots.needle.67percent"
        case .notchType: "rectangle.topthird.inset.filled"
        case .monitor: "display.2"
        case .notifications: "bell.badge.fill"
        case .position: "arrow.up.and.down.and.arrow.left.and.right"
        case .language: "globe"
        case .support: "mug.fill"
        }
    }

    var color: Color {
        switch self {
        case .connection: .cyan
        case .display: .green
        case .notchType: .orange
        case .monitor: .teal
        case .notifications: .red
        case .position: .purple
        case .language: .indigo
        case .support: .orange
        }
    }
}

/// Remembers the selected category, so the menu and the notch can open a specific one directly.
@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var selection: SettingsTab = .connection
}

struct SettingsWindowView: View {
    @ObservedObject var navigation: SettingsNavigation
    /// When the language changes, the whole window redraws in the new language.
    @ObservedObject private var appSettings = NotchSettings.shared

    private var selection: Binding<SettingsTab?> {
        Binding(get: { navigation.selection },
                set: { if let tab = $0 { navigation.selection = tab } })
    }

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsTab.allCases, selection: selection) { tab in
                Label {
                    Text(tab.title)
                } icon: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(tab.color.gradient, in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(.vertical, 2)
                .tag(tab)
            }
            .listStyle(.sidebar)
            .frame(width: 250)

            Divider()

            ScrollView {
                Group {
                    switch navigation.selection {
                    case .connection:
                        // After the first successful connection, move on to choosing sensors.
                        SettingsView(onConnected: { navigation.selection = .display })
                    case .display:
                        DisplaySettingsView()
                    case .notchType:
                        NotchStyleSettingsView()
                    case .monitor:
                        MonitorSettingsView()
                    case .notifications:
                        NotificationSettingsView()
                    case .position:
                        PositionSettingsView()
                    case .language:
                        LanguageSettingsView()
                    case .support:
                        SupportSettingsView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 840, height: 580)
        .id(appSettings.language)
    }
}
