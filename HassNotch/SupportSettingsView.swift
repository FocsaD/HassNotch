import SwiftUI
import AppKit

/// Donation and project links. nil = not set yet: the button is disabled.
enum SupportLinks {
    /// The donation page (Ko-fi).
    static let donation: URL? = URL(string: "https://ko-fi.com/V8Q82B3VFL")
    /// The project page on GitHub.
    static let project: URL? = URL(string: "https://github.com/FocsaD/HassNotch")
    /// Address for feature ideas and bug reports.
    static let email = "hassnotch@focsa.ro"
}

/// The "Buy me a beer" category: supporting the project.
struct SupportSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L("Buy me a beer")).font(.title2.bold())

            HStack(alignment: .top, spacing: 18) {
                Text("🍺")
                    .font(.system(size: 56))
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("HassNotch este gratuit și open source. Dacă îți este util și vrei să susții dezvoltarea lui, poți să-mi faci cinste cu o bere. Mulțumesc!"))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L("Fiecare donație ajută la noi funcții, reparații și la menținerea aplicației gratuite pentru toată lumea."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 12) {
                Button {
                    if let url = SupportLinks.donation { NSWorkspace.shared.open(url) }
                } label: {
                    Label(L("Cumpără-mi o bere"), systemImage: "mug.fill")
                        .padding(.horizontal, 6)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(SupportLinks.donation == nil)

                Button {
                    if let url = SupportLinks.project { NSWorkspace.shared.open(url) }
                } label: {
                    Label(L("Proiectul pe GitHub"), systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .controlSize(.large)
                .disabled(SupportLinks.project == nil)
            }

            if SupportLinks.donation == nil {
                Label(L("Pagina de donații va fi disponibilă în curând."), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(L("Idei sau probleme?")).font(.headline)
                Text(L("Ai găsit o problemă sau vrei o funcție nouă? Scrie-mi, citesc fiecare mesaj."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    let subject = "HassNotch \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")"
                    var mail = URLComponents()
                    mail.scheme = "mailto"
                    mail.path = SupportLinks.email
                    mail.queryItems = [URLQueryItem(name: "subject", value: subject)]
                    if let url = mail.url { NSWorkspace.shared.open(url) }
                } label: {
                    Label(SupportLinks.email, systemImage: "envelope.fill")
                }
                .textSelection(.enabled)
            }

            Divider()

            Text(L("Alte moduri de a ajuta: dă o stea proiectului pe GitHub, raportează problemele găsite sau recomandă HassNotch altor utilizatori Home Assistant."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
