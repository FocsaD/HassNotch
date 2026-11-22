import SwiftUI
import AppKit

extension NSScreen {
    /// The display's stable ID (CGDirectDisplayID).
    var displayID: Int {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue ?? 0
    }
}

/// The "Position" category: where Dynamic Island sits on screen. Default: centered, at the top.
struct PositionSettingsView: View {
    @ObservedObject private var settings = NotchSettings.shared

    /// How far it can move left/right on the chosen screen, so the expanded island (460 pt) stays on screen.
    private var maxHorizontalOffset: Double {
        let width = settings.islandScreen?.frame.width ?? 1440
        return max(0, Double(width / 2 - NotchView.islandWindowWidth / 2 - 8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L("Poziționare")).font(.title2.bold())
            if settings.style == .notch {
                Label(L("Poziționarea e disponibilă doar pentru Dynamic Island. Notch-ul clasic stă mereu peste camera fizică a laptopului, deci nu are sens să fie mutat."),
                      systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(L("Mută Dynamic Island unde îți convine. Modificările se văd imediat; implicit stă centrată, sus."))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(L("Orizontal"))
                                Spacer()
                                Text(horizontalLabel).monospacedDigit().foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.islandOffsetX,
                                   in: -maxHorizontalOffset...maxHorizontalOffset, step: 1)
                            HStack {
                                Button(L("Stânga")) { settings.islandOffsetX = -maxHorizontalOffset }
                                Button(L("Centru")) { settings.islandOffsetX = 0 }
                                Button(L("Dreapta")) { settings.islandOffsetX = maxHorizontalOffset }
                            }
                            .controlSize(.small)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(L("Distanța de marginea de sus"))
                                Spacer()
                                Text(settings.islandOffsetY == 0 ? L("lipită sus") : "\(Int(settings.islandOffsetY)) pt")
                                    .monospacedDigit().foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.islandOffsetY, in: 0...240, step: 1)
                            Text(L("La 0 stă în bara de meniu; cu valori mai mari coboară sub ea."))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                }

                Button(L("Resetează la poziția implicită")) {
                    settings.islandOffsetX = 0
                    settings.islandOffsetY = 0
                }
                .disabled(settings.islandOffsetX == 0 && settings.islandOffsetY == 0)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var horizontalLabel: String {
        let value = Int(settings.islandOffsetX)
        if value == 0 { return L("centrată") }
        return value < 0 ? L("%@ pt la stânga", -value) : L("%@ pt la dreapta", value)
    }
}
