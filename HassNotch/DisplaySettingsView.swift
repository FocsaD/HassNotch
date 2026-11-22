import SwiftUI

struct DisplaySettingsView: View {
    @ObservedObject private var manager = HomeAssistantManager.shared
    @ObservedObject private var appearance = NotchSettings.shared

    private var canAdd: Bool { manager.displayed.count < NotchLayout.maxItems }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L("Informații afișate")).font(.title2.bold())
            Text(L("Alege ce entități apar în insulă. Încap maximum %@: câte %@ pe rând, pe cel mult %@ rânduri. Indicatoarele se micșorează automat pe măsură ce adaugi. Selecțiile se salvează automat.", NotchLayout.maxItems, NotchLayout.maxColumns, NotchLayout.maxRows))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                if manager.displayed.isEmpty {
                    Text(L("Nicio entitate afișată. Apasă + ca să adaugi una."))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    ForEach($manager.displayed) { $slot in
                        EntityRow(slot: $slot,
                                  number: (manager.displayed.firstIndex(of: slot) ?? 0) + 1) {
                            withAnimation { manager.displayed.removeAll { $0.id == slot.id } }
                        }
                        if slot.id != manager.displayed.last?.id { Divider() }
                    }
                }
                Divider()
                // Bottom bar, like in System Settings.
                HStack(spacing: 0) {
                    Button {
                        withAnimation { manager.displayed.append(DisplayedEntity()) }
                    } label: {
                        Image(systemName: "plus").frame(width: 28, height: 22)
                    }
                    .help(L("Adaugă o entitate"))
                    .disabled(!canAdd)
                    Divider().frame(height: 16)
                    Button {
                        withAnimation { _ = manager.displayed.popLast() }
                    } label: {
                        Image(systemName: "minus").frame(width: 28, height: 22)
                    }
                    .help(L("Scoate ultima entitate"))
                    .disabled(manager.displayed.isEmpty)
                    Spacer()
                    Text(L("%@ din %@", manager.displayed.count, NotchLayout.maxItems))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 10)
                }
                .buttonStyle(.borderless)
                .padding(4)
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L("Animație cifre")).font(.headline)
                    Spacer()
                    Picker(L("Animație cifre"), selection: $appearance.digitAnimation) {
                        ForEach(DigitAnimation.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 320)
                }
                Text(L("Rolă: cifrele se derulează în sus sau în jos prin valorile intermediare, ca la pompele de benzină vechi. Simplă: cifra se schimbă direct."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(manager.readingsStatus)
                if !manager.rangesStatus.isEmpty { Text(manager.rangesStatus) }
                Text(L("Valorile se actualizează în timp real (sau la 30 de secunde, dacă conexiunea în timp real nu e disponibilă). Intervalele (min/max) se iau din cardurile Gauge ale dashboard-urilor Home Assistant, dacă nu le scrii tu."))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(L("Recitește intervalele din HA")) { Task { await manager.refreshDashboardRanges() } }
                    .disabled(manager.loadingRanges)
                Button(L("Actualizează acum")) { Task { await manager.refreshEntities() } }
                    .disabled(manager.refreshing)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await manager.refreshEntities() }
    }
}

/// One row of the list: entity picker, label, icon and delete button.
private struct EntityRow: View {
    @Binding var slot: DisplayedEntity
    let number: Int
    let onRemove: () -> Void
    @ObservedObject private var manager = HomeAssistantManager.shared

    private var entity: HAEntity? { manager.entity(slot.entityID) }

    /// The automatic range (ignoring manual values), shown as a hint in the fields.
    private var automaticRange: (range: GaugeRange, source: GaugeRangeSource)? {
        var automatic = slot
        automatic.minValue = nil
        automatic.maxValue = nil
        return manager.range(for: automatic)
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    // MARK: - Showing on the collapsed island

    @ObservedObject private var notchSettings = NotchSettings.shared

    private var alwaysShowLimit: Int { NotchView.maxCollapsed(notchSettings.style) }
    private var alwaysShowCount: Int {
        manager.displayed.filter { $0.alwaysShow == true && !$0.entityID.isEmpty }.count
    }

    /// Slots allowed right now (they depend on how many values are shown, for symmetry).
    private var allowedPositions: [CollapsedPosition] {
        CollapsedPosition.allowed(for: notchSettings.style,
                                  count: CollapsedPosition.activeCount(manager.displayed, style: notchSettings.style))
    }

    /// The slot this value currently occupies on the collapsed island (nil = it doesn't fit).
    private var resolvedPosition: CollapsedPosition? {
        CollapsedPosition.layout(manager.displayed, style: notchSettings.style)
            .first { $0.value.id == slot.id }?.key
    }

    private var alwaysShowToggle: some View {
        let isOn = slot.alwaysShow == true
        let limitReached = !isOn && alwaysShowCount >= alwaysShowLimit
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Toggle(L("Afișează mereu (și pe insula închisă)"),
                       isOn: Binding(get: { isOn }, set: { manager.setAlwaysShow($0, for: slot.id) }))
                    .disabled(limitReached)
                if isOn, let position = resolvedPosition, allowedPositions.count > 1 {
                    // Pick a slot; if it's taken, the two values swap places.
                    Picker(L("Poziție"), selection: Binding(get: { position },
                                                         set: { manager.setCollapsedPosition($0, for: slot.id) })) {
                        ForEach(allowedPositions) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: allowedPositions.count == 2 ? 170 : 240)
                }
            }
            if isOn && resolvedPosition == nil {
                Text(L("Nu mai e loc pe insula închisă pentru %@.", notchSettings.style.title))
                    .font(.caption).foregroundStyle(.orange)
            } else {
                Text(limitReached
                     ? L("Sunt deja %@ valori afișate mereu — maximul pentru %@.", alwaysShowLimit, notchSettings.style.title)
                     : L("Dynamic Island: 1 valoare la mijloc, 2 în stânga și dreapta, 3 pe toate locurile. Notch: maximum 2, stânga și dreapta."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }

    // MARK: - Charging state

    /// The entity looks like a battery: device class "battery" or "battery/baterie/soc" in its name.
    private var isBatteryLike: Bool {
        if entity?.attributes.device_class == "battery" { return true }
        let text = (slot.entityID + " " + (entity?.name ?? "")).lowercased()
        return ["batter", "baterie", "_soc", "state_of_charge"].contains { text.contains($0) }
    }

    private var chargeEnabled: Binding<Bool> {
        Binding(get: { slot.chargeEnabled == true }, set: { slot.chargeEnabled = $0 })
    }
    private var chargeSource: Binding<ChargeSource> {
        Binding(get: { slot.chargeSource ?? .automatic },
                set: { slot.chargeSource = $0; slot.chargeEntityID = nil })
    }
    private var chargeEntity: Binding<String> {
        Binding(get: { slot.chargeEntityID ?? "" }, set: { slot.chargeEntityID = $0.isEmpty ? nil : $0 })
    }
    private var chargeInvert: Binding<Bool> {
        Binding(get: { slot.chargeInvert == true }, set: { slot.chargeInvert = $0 })
    }

    /// Sensors suitable for the chosen source, with the ones that look related to the battery first.
    private var chargeCandidates: [HAEntity] {
        let source = slot.chargeSource ?? .automatic
        let filtered = manager.displayCandidates.filter { candidate in
            switch source {
            case .automatic: return false
            case .stateSensor:
                return candidate.entity_id.hasPrefix("binary_sensor.") || candidate.numericValue == nil
            case .powerSensor:
                let unit = candidate.attributes.unit_of_measurement?.lowercased()
                return unit == "w" || unit == "kw"
            }
        }
        func batteryish(_ e: HAEntity) -> Bool {
            let text = (e.entity_id + " " + e.name).lowercased()
            return text.contains("batt") || text.contains("bater") || text.contains("charg")
        }
        return filtered.filter(batteryish) + filtered.filter { !batteryish($0) }
    }

    /// Sensors from the same device as the battery: IDs with the same prefix
    /// (e.g. "inverter_…", "my_car_…"), closest matches first.
    private var chargeSuggestions: [HAEntity] {
        let main = Array(entity?.objectID ?? slot.entityID.split(separator: ".").last.map(String.init) ?? "")
        guard main.count >= 4 else { return [] }
        func sharedPrefix(_ candidate: HAEntity) -> Int {
            zip(main, candidate.objectID).prefix { $0 == $1 }.count
        }
        return chargeCandidates
            .map { ($0, sharedPrefix($0)) }
            .filter { $0.1 >= 6 && $0.0.entity_id != slot.entityID }
            .sorted { $0.1 > $1.1 }
            .prefix(8)
            .map(\.0)
    }

    private var chargeEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(L("Arată pe notch dacă se încarcă (⚡) sau se descarcă (↓)"), isOn: chargeEnabled)
            if slot.chargeEnabled == true {
                Picker(L("Sursă"), selection: chargeSource) {
                    ForEach(ChargeSource.allCases) { Text($0.title).tag($0) }
                }
                .frame(maxWidth: 380)
                switch slot.chargeSource ?? .automatic {
                case .automatic:
                    Text(L("Se deduce din cum se schimbă valoarea: urcă = se încarcă, scade = se descarcă. Mai lent, pentru că procentul se schimbă rar."))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .stateSensor, .powerSensor:
                    EntitySearchPicker(placeholder: L("Alege senzorul…"),
                                       selection: chargeEntity,
                                       candidates: chargeCandidates,
                                       suggestions: chargeSuggestions)
                    .frame(maxWidth: 480)
                    if slot.chargeSource == .powerSensor {
                        Toggle(L("Inversează semnul (pentru invertoarele unde pozitiv = descărcare)"), isOn: chargeInvert)
                    }
                }
                if let state = manager.chargeState(for: slot) {
                    Text(L("Acum: %@", state.description))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .font(.callout)
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Asking Home Assistant for a range only makes sense for numeric values.
    private var supportsRange: Bool { !slot.entityID.hasPrefix("binary_sensor.") }

    /// Prefills min/max with the values from Home Assistant when they are empty and known.
    private func fillFromHomeAssistantIfEmpty() {
        guard supportsRange, slot.minValue == nil, slot.maxValue == nil,
              let automatic = automaticRange else { return }
        slot.minValue = automatic.range.min
        slot.maxValue = automatic.range.max
    }

    private enum RangeState { case fromHA(GaugeRangeSource), manual, missing, invalid }

    private var rangeState: RangeState {
        guard let min = slot.minValue, let max = slot.maxValue else { return .missing }
        guard max > min else { return .invalid }
        if let automatic = automaticRange, automatic.range == GaugeRange(min: min, max: max) {
            return .fromHA(automatic.source)
        }
        return .manual
    }

    /// Min / max for each entity: prefilled from Home Assistant when known,
    /// otherwise entered by the user. Saved automatically.
    private var rangeEditor: some View {
        HStack(spacing: 8) {
            Text(L("Interval")).foregroundStyle(.secondary)
            TextField("Min", value: $slot.minValue, format: .number, prompt: Text("min"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            Text("–").foregroundStyle(.secondary)
            TextField("Max", value: $slot.maxValue, format: .number, prompt: Text("max"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            if let unit = entity?.attributes.unit_of_measurement, !unit.isEmpty {
                Text(unit).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Group {
                switch rangeState {
                case .fromHA(let source):
                    Label(L("preluat %@", source.description), systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                case .manual:
                    Label(L("setat manual"), systemImage: "pencil.circle")
                        .foregroundStyle(.secondary)
                case .missing:
                    Label(L("HA nu are interval · completează min și max"), systemImage: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                case .invalid:
                    Label(L("max trebuie să fie mai mare decât min"), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .lineLimit(2)
            if let automatic = automaticRange,
               automatic.range != GaugeRange(min: slot.minValue ?? .nan, max: slot.maxValue ?? .nan) {
                Button(L("Ia din HA")) {
                    slot.minValue = automatic.range.min
                    slot.maxValue = automatic.range.max
                }
                .controlSize(.small)
                .help(L("Pune intervalul definit în Home Assistant"))
            }
        }
        .font(.callout)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 22)
                .background(.quaternary, in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                EntitySearchPicker(placeholder: L("Alege o entitate…"),
                                   selection: $slot.entityID,
                                   candidates: manager.displayCandidates)
                HStack(spacing: 10) {
                    TextField(L("Etichetă"), text: $slot.label,
                              prompt: Text(entity?.name ?? L("Etichetă (opțional)")))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: slot.label) {
                            if slot.label.count > DisplayedEntity.maxLabelLength {
                                slot.label = String(slot.label.prefix(DisplayedEntity.maxLabelLength))
                            }
                        }
                    Text("\(slot.label.count)/\(DisplayedEntity.maxLabelLength)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Afișare")).font(.callout).foregroundStyle(.secondary)
                    DisplayStylePicker(style: Binding(get: { slot.displayStyle },
                                                      set: { slot.style = $0 }),
                                       icon: slot.icon.isEmpty ? EntityIcons.automatic(for: entity) : slot.icon)
                }
                HStack(spacing: 10) {
                    Picker(L("Iconiță"), selection: $slot.icon) {
                        ForEach(EntityIcons.choices, id: \.symbol) { choice in
                            Label(choice.name,
                                  systemImage: choice.symbol.isEmpty ? EntityIcons.automatic(for: entity) : choice.symbol)
                                .tag(choice.symbol)
                        }
                    }
                    .frame(width: 210)
                }
                if !slot.entityID.isEmpty {
                    alwaysShowToggle
                }
                if !slot.entityID.isEmpty && supportsRange {
                    rangeEditor
                }
                if !slot.entityID.isEmpty && (isBatteryLike || slot.chargeEnabled == true) {
                    chargeEditor
                }
                if !slot.entityID.isEmpty {
                    Text(slot.entityID)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help(L("Scoate această entitate"))
        }
        .padding(12)
        .onAppear(perform: fillFromHomeAssistantIfEmpty)
        // A new entity was chosen: the old range no longer applies.
        .onChange(of: slot.entityID) {
            slot.minValue = nil
            slot.maxValue = nil
            fillFromHomeAssistantIfEmpty()
        }
        // Data from HA may arrive after the window has opened.
        .onChange(of: manager.readingsUpdated) { fillFromHomeAssistantIfEmpty() }
        .onChange(of: manager.dashboardRanges) { fillFromHomeAssistantIfEmpty() }
    }
}
