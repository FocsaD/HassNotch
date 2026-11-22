import SwiftUI
import AppKit

struct SettingsView: View {
    var onConnected: () -> Void
    @ObservedObject private var manager = HomeAssistantManager.shared
    @State private var address = ""
    @State private var token = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "house.fill")
                    .font(.system(size: 28)).foregroundStyle(.cyan)
                    .frame(width: 56, height: 56)
                    .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Casa ta, în HassNotch")).font(.title2.bold())
                    Text(L("Conectează Home Assistant pentru a începe."))
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Adresa Home Assistant")).font(.headline)
                    TextField("http://homeassistant.local:8123", text: $address)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("haServerAddress")
                    HStack {
                        Text(L("Adresa serverului, fără /lovelace sau /dashboard."))
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(L("Pe acest Mac")) { address = "http://127.0.0.1:8123" }
                            .controlSize(.small)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Token de acces")).font(.headline)
                    SecureField(manager.hasSavedToken ? L("Token salvat · lasă gol pentru a-l păstra") : L("Lipește tokenul aici"), text: $token)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("haAccessToken")
                    Label(L("Păstrat în siguranță în Keychain pe acest Mac."), systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DisclosureGroup(L("De unde iau tokenul?")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("În Home Assistant, deschide profilul tău → Securitate → Tokenuri de acces de lungă durată. Creează un token numit HassNotch și lipește-l în câmpul de mai sus."))
                            .font(.callout).foregroundStyle(.secondary)
                        Button(L("Deschide profilul Home Assistant")) {
                            guard let url = HomeAssistantManager.normalizedURL(address) else { return }
                            NSWorkspace.shared.open(url.appendingPathComponent("profile/security"))
                        }.disabled(HomeAssistantManager.normalizedURL(address) == nil)
                    }.padding(.top, 8)
                }
            }
            .padding(20)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
            .disabled(manager.isConnecting)
            HStack(alignment: .top, spacing: 10) {
                if manager.isConnecting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: manager.connected ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(manager.connected ? .green : .secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(manager.status).font(.callout).fixedSize(horizontal: false, vertical: true)
                    if let date = manager.lastChecked, manager.connected {
                        Text(L("%@ · HA %@ · verificat la %@", manager.homeName, manager.version, date.formatted(date: .omitted, time: .shortened)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }.frame(minHeight: 44, alignment: .top)
            HStack {
                Text(L("Conexiune directă cu serverul tău."))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(manager.isConnecting ? L("Se conectează…") : L("Salvează și conectează")) {
                    Task {
                        if await manager.connect(address: address, token: token) {
                            token = ""
                            onConnected()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(manager.isConnecting || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { address = manager.serverURL }
    }
}
