import SwiftUI

/// Picking an entity from a long list: a button that opens a small popover with
/// search (by name or ID, multiple words), suggestions at the top and, on each row,
/// the name, ID and current value — so you can easily tell five "Battery State" entities apart.
struct EntitySearchPicker: View {
    let placeholder: String
    @Binding var selection: String
    let candidates: [HAEntity]
    var suggestions: [HAEntity] = []

    @State private var isOpen = false
    @State private var query = ""

    private var selected: HAEntity? { candidates.first { $0.id == selection } }

    var body: some View {
        Button { isOpen = true } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    if let selected {
                        Text(selected.name).lineLimit(1)
                        Text("\(selected.entity_id) · \(selected.summaryText)")
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    } else if !selection.isEmpty {
                        Text(L("Salvat · indisponibil acum")).lineLimit(1)
                        Text(selection).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    } else {
                        Text(placeholder).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(.background))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) { searchPanel }
    }

    /// Every search word must appear in the name or the ID.
    private func matches(_ entity: HAEntity) -> Bool {
        let words = query.lowercased().split(separator: " ").map(String.init)
        guard !words.isEmpty else { return true }
        let text = (entity.name + " " + entity.entity_id).lowercased()
        return words.allSatisfy(text.contains)
    }

    private var searchPanel: some View {
        let shownSuggestions = suggestions.filter(matches)
        let suggestedIDs = Set(shownSuggestions.map(\.id))
        let results = candidates.filter { matches($0) && !suggestedIDs.contains($0.id) }
        return VStack(spacing: 0) {
            TextField(L("Caută după nume sau ID (ex. „inverter state”)…"), text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(10)
            List {
                if !shownSuggestions.isEmpty {
                    Section(L("Sugestii")) {
                        ForEach(shownSuggestions) { row($0) }
                    }
                }
                Section(query.isEmpty ? L("Toate (%@)", results.count) : L("Rezultate (%@)", results.count)) {
                    ForEach(results.prefix(300)) { row($0) }
                    if results.count > 300 {
                        Text(L("Încă %@… scrie mai mult ca să restrângi.", results.count - 300))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if !selection.isEmpty {
                Divider()
                Button(L("Golește alegerea")) {
                    selection = ""
                    isOpen = false
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
        }
        .frame(width: 480, height: 440)
    }

    private func row(_ entity: HAEntity) -> some View {
        Button {
            selection = entity.id
            query = ""
            isOpen = false
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entity.name).lineLimit(1)
                    Text(entity.entity_id).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(entity.summaryText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if entity.id == selection {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension HAEntity {
    /// The part after the domain: "sensor.inverter_battery_state" → "inverter_battery_state".
    var objectID: String {
        entity_id.split(separator: ".", maxSplits: 1).last.map(String.init) ?? entity_id
    }
}
