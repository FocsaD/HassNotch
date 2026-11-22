import SwiftUI

/// An entity chosen to be shown on the island.
struct DisplayedEntity: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Home Assistant entity ID, e.g. sensor.car_battery. Empty = not chosen yet.
    var entityID: String = ""
    /// Label shown under the value. Empty = the entity's name from Home Assistant.
    var label: String = ""
    /// SF Symbol shown next to the label. Empty = chosen automatically from the sensor type.
    var icon: String = ""
    /// Manually set range. Empty = taken from Home Assistant.
    var minValue: Double?
    var maxValue: Double?

    /// Display style. Empty = horseshoe (also for lists saved by older versions).
    var style: EntityDisplayStyle?
    var displayStyle: EntityDisplayStyle { style ?? .horseshoe }

    /// The value is always visible, also on the collapsed island (max. 3 on Dynamic Island, 2 on the notch).
    var alwaysShow: Bool?
    /// Where it sits on the collapsed island. Empty = first free slot.
    var collapsedPosition: CollapsedPosition?

    /// Shows next to the icon whether the battery is charging (⚡) or discharging (↓).
    var chargeEnabled: Bool?
    /// Where the charging state comes from. Empty = automatic.
    var chargeSource: ChargeSource?
    /// The state or power sensor used for the charging state.
    var chargeEntityID: String?
    /// For the power sensor: inverts the sign (some inverters report positive = discharging).
    var chargeInvert: Bool?

    /// Maximum length of a custom label, so it fits between the ends of the arc.
    static let maxLabelLength = 14
}

/// A value's slot on the collapsed island.
enum CollapsedPosition: String, Codable, CaseIterable, Identifiable {
    case left
    case center
    case right

    var id: Self { self }

    var title: String {
        switch self {
        case .left: L("Stânga")
        case .center: L("Mijloc")
        case .right: L("Dreapta")
        }
    }

    /// Allowed slots, so the island looks symmetric. On the notch the middle is the camera, so only
    /// left and right. On Dynamic Island: 1 value → middle; 2 → left and right; 3 → all.
    static func allowed(for style: NotchStyle, count: Int) -> [CollapsedPosition] {
        if style == .notch { return [.left, .right] }
        switch count {
        case ...1: return [.center]
        case 2: return [.left, .right]
        default: return [.left, .center, .right]
        }
    }

    /// The order in which free slots are filled.
    static func preference(for style: NotchStyle, count: Int) -> [CollapsedPosition] {
        let allowed = allowed(for: style, count: count)
        return [.center, .right, .left].filter(allowed.contains)
    }

    /// How many values are marked "always show" (as many as fit).
    static func activeCount(_ displayed: [DisplayedEntity], style: NotchStyle) -> Int {
        min(displayed.filter { $0.alwaysShow == true && !$0.entityID.isEmpty }.count,
            style == .notch ? 2 : 3)
    }

    /// Who goes where: each marked entity gets its chosen slot if it's allowed and free;
    /// the others take the first free slot. Two values never end up in the same slot.
    static func layout(_ displayed: [DisplayedEntity], style: NotchStyle) -> [CollapsedPosition: DisplayedEntity] {
        let count = activeCount(displayed, style: style)
        let allowed = allowed(for: style, count: count)
        var layout: [CollapsedPosition: DisplayedEntity] = [:]
        var pending: [DisplayedEntity] = []
        for slot in displayed where slot.alwaysShow == true && !slot.entityID.isEmpty {
            if let position = slot.collapsedPosition, allowed.contains(position), layout[position] == nil {
                layout[position] = slot
            } else {
                pending.append(slot)
            }
        }
        for slot in pending {
            guard let free = preference(for: style, count: count).first(where: { layout[$0] == nil }) else { break }
            layout[free] = slot
        }
        return layout
    }
}

/// Where we learn whether a battery is charging or discharging.
enum ChargeSource: String, Codable, CaseIterable, Identifiable {
    /// From the trend of the percentage: rising = charging, falling = discharging.
    case automatic
    /// A yes/no sensor ("battery_charging") or a text sensor ("Charging", "Discharging", "Idle").
    case stateSensor
    /// A power sensor in W/kW: the sign shows the direction.
    case powerSensor

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: L("Automat (din evoluția valorii)")
        case .stateSensor: L("Senzor de stare")
        case .powerSensor: L("Senzor de putere (W)")
        }
    }
}

/// A battery's charging state.
enum ChargeState: Equatable {
    case charging
    case discharging
    case idle

    var description: String {
        switch self {
        case .charging: L("se încarcă")
        case .discharging: L("se descarcă")
        case .idle: L("în repaus")
        }
    }
}

/// How an entity is drawn on the island.
enum EntityDisplayStyle: String, Codable, CaseIterable, Identifiable {
    case horseshoe
    case verticalBar
    case horizontalBar
    case textOnly
    case needle

    var id: Self { self }

    var title: String {
        switch self {
        case .horseshoe: L("Potcoavă")
        case .verticalBar: L("Bară verticală")
        case .horizontalBar: L("Bară orizontală")
        case .textOnly: L("Numai text")
        case .needle: L("Indicator cu ac")
        }
    }

    var symbol: String {
        switch self {
        case .horseshoe: "gauge.open.with.lines.needle.33percent"
        case .verticalBar: "rectangle.portrait.bottomhalf.filled"
        case .horizontalBar: "rectangle.lefthalf.filled"
        case .textOnly: "textformat.size"
        case .needle: "gauge.with.needle"
        }
    }
}

/// The range over which a gauge's arc fills.
struct GaugeRange: Codable, Equatable {
    var min: Double
    var max: Double

    /// How much of the arc is filled (0…1) for a value.
    func fraction(of value: Double) -> Double {
        guard max > min else { return 0 }
        return Swift.min(1, Swift.max(0, (value - min) / (max - min)))
    }
}

/// Where a gauge's range comes from, in order of priority.
enum GaugeRangeSource {
    case manual      // entered manually in Settings
    case dashboard   // from a Gauge card on a Home Assistant dashboard
    case entity      // the entity's min/max attributes (number / input_number)
    case percent     // unit is %, so 0–100

    var description: String {
        switch self {
        case .manual: L("setat manual")
        case .dashboard: L("din cardul Gauge din HA")
        case .entity: L("din atributele entității în HA")
        case .percent: L("pentru procente (0–100)")
        }
    }
}

/// Icons that can be chosen in Settings (empty = automatic).
enum EntityIcons {
    static var choices: [(symbol: String, name: String)] { [
        ("", L("Automat")),
        ("house.fill", L("Casă")),
        ("car.fill", L("Mașină")),
        ("battery.75percent", L("Baterie")),
        ("bolt.fill", L("Putere")),
        ("powerplug.fill", L("Priză")),
        ("sun.max.fill", L("Soare")),
        ("thermometer.medium", L("Temperatură")),
        ("humidity.fill", L("Umiditate")),
        ("drop.fill", L("Apă")),
        ("flame.fill", L("Gaz / foc")),
        ("fan.fill", L("Ventilator")),
        ("lightbulb.fill", L("Lumină")),
        ("leaf.fill", L("Eco")),
        ("wifi", L("Rețea")),
        ("figure.walk", L("Mișcare")),
    ] }

    /// The icon matching the Home Assistant sensor type.
    static func automatic(for entity: HAEntity?) -> String {
        switch entity?.attributes.device_class {
        case "battery": "battery.75percent"
        case "temperature": "thermometer.medium"
        case "humidity", "moisture": "humidity.fill"
        case "power", "apparent_power": "bolt.fill"
        case "energy": "bolt.circle.fill"
        case "voltage", "current": "bolt"
        case "illuminance", "irradiance": "sun.max.fill"
        case "gas": "flame.fill"
        case "water": "drop.fill"
        case "motion", "occupancy", "presence": "figure.walk"
        case "door", "garage_door": "door.left.hand.closed"
        case "window": "window.vertical.closed"
        case "signal_strength": "wifi"
        default: "gauge.with.dots.needle.33percent"
        }
    }
}

/// How gauges are laid out on the expanded island: at most 4 per row, 2 rows.
struct NotchLayout {
    static let maxColumns = 4
    static let maxRows = 2
    static let maxItems = maxColumns * maxRows
    static let spacing: CGFloat = 18
    static let sidePadding: CGFloat = 20
    static let maxCell: CGFloat = 136
    /// Maximum grid height: gauges shrink so they also fit vertically.
    static let maxContentHeight: CGFloat = 220
    /// Space below the grid, for the settings gear.
    static let bottomArea: CGFloat = 46

    let rows: Int
    let columns: Int
    let cell: CGFloat

    init(count: Int, width: CGFloat) {
        let n = min(max(count, 1), Self.maxItems)
        rows = Int((Double(n) / Double(Self.maxColumns)).rounded(.up))
        // Split evenly: 5 entities = 3 + 2, not 4 + 1.
        columns = Int((Double(n) / Double(rows)).rounded(.up))
        let availableWidth = width - 2 * Self.sidePadding - CGFloat(columns - 1) * Self.spacing
        let availableHeight = Self.maxContentHeight - CGFloat(rows - 1) * Self.spacing
        cell = min(Self.maxCell,
                   (availableWidth / CGFloat(columns)).rounded(.down),
                   (availableHeight / CGFloat(rows)).rounded(.down))
    }

    var contentHeight: CGFloat { CGFloat(rows) * cell + CGFloat(rows - 1) * Self.spacing }

    func expandedHeight(contentTop: CGFloat) -> CGFloat {
        contentTop + contentHeight + Self.bottomArea
    }

    /// Maximum height (all entities) — how tall the window has to be.
    static func maxExpandedHeight(width: CGFloat, contentTop: CGFloat) -> CGFloat {
        (1...maxItems)
            .map { NotchLayout(count: $0, width: width).expandedHeight(contentTop: contentTop) }
            .max().map { ceil($0) } ?? 0   // whole number of points: the window sits exactly at the top edge
    }
}

/// An entity's gauge. Scales with `size` (136 = original size).
struct EntityGauge: View {
    let slot: DisplayedEntity
    let entity: HAEntity?
    let range: GaugeRange?
    let size: CGFloat
    /// Charging state; nil = not shown.
    var charge: ChargeState? = nil
    /// Namespace shared with the collapsed island: digits and icon "fly" between the two when opening/closing.
    var morph: Namespace.ID? = nil

    @ObservedObject private var appearance = NotchSettings.shared
    /// The previous value, so the rollers know whether to roll forward or backward.
    @State private var lastValue: Double?
    private var increasing: Bool {
        guard let new = entity?.numericValue, let old = lastValue else { return true }
        return new >= old
    }

    /// The tile has a thin border; the drawing is centered inside it, with padding.
    private var contentSize: CGFloat { size * 0.86 }
    private var scale: CGFloat { contentSize / 136 }
    /// How much of the arc is filled; nil when there is no numeric value or range.
    private var fraction: Double? {
        guard let range, let value = entity?.numericValue else { return nil }
        return range.fraction(of: value)
    }

    private var title: String {
        let custom = slot.label.trimmingCharacters(in: .whitespaces)
        if !custom.isEmpty { return custom }
        return entity?.name ?? "—"
    }

    private var icon: String {
        slot.icon.isEmpty ? EntityIcons.automatic(for: entity) : slot.icon
    }

    /// Color based on how full the gauge is (min → max), in 10% steps:
    /// red at 0–10%, through orange and yellow around the middle, bright green at 90–100%.
    static let levelColors: [Color] = [
        Color(red: 0.83, green: 0.16, blue: 0.16), //  0–10%  red
        Color(red: 0.92, green: 0.29, blue: 0.22), // 10–20%  lighter red
        Color(red: 0.95, green: 0.40, blue: 0.19), // 20–30%  red-orange
        Color(red: 0.96, green: 0.52, blue: 0.16), // 30–40%  orange
        Color(red: 0.97, green: 0.62, blue: 0.13), // 40–50%  amber-orange
        Color(red: 0.98, green: 0.72, blue: 0.11), // 50–60%  yellow-orange
        Color(red: 0.91, green: 0.79, blue: 0.13), // 60–70%  yellow
        Color(red: 0.71, green: 0.78, blue: 0.20), // 70–80%  yellow-green
        Color(red: 0.42, green: 0.73, blue: 0.27), // 80–90%  light green
        Color(red: 0.07, green: 0.63, blue: 0.31), // 90–100% vivid, deep green
    ]

    private var tint: Color {
        guard let fraction else { return .gray }
        let level = min(Self.levelColors.count - 1, max(0, Int(fraction * 10)))
        return Self.levelColors[level]
    }

    /// The fill is always drawn (0 when there is no value), so the animation starts from the
    /// current position, not from nothing.
    private var shownFraction: Double { fraction ?? 0 }

    /// Animation when the value changes: the fill rises/falls smoothly, the color blends
    /// into the new shade and the digits roll.
    static let valueAnimation: Animation = .easeInOut(duration: 0.8)

    /// Line width, proportional to the gauge size.
    private var lineWidth: CGFloat { max(4, 9 * scale) }

    var body: some View {
        // All styles use the same label at the same height, so they line up
        // nicely in a row even when horseshoes and bars are mixed.
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(.white.opacity(0.03))
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .strokeBorder(.white.opacity(0.32), lineWidth: 0.75)
            ZStack {
                // The full square keeps the grid fixed, so positions match across all styles.
                Color.clear.frame(width: contentSize, height: contentSize)
                switch slot.displayStyle {
                case .horseshoe: horseshoe
                case .verticalBar: verticalBar
                case .horizontalBar: horizontalBar
                case .textOnly: textOnly
                case .needle: needleGauge
                }
                labelView
            }
            .frame(width: contentSize, height: contentSize)
        }
        .frame(width: size, height: size)
        .animation(Self.valueAnimation, value: fraction)
        .animation(Self.valueAnimation, value: entity?.valueText)
        .onAppear { lastValue = entity?.numericValue }
        .onChange(of: entity?.numericValue) { _, new in lastValue = new }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(entity?.valueText ?? "indisponibil") \(entity?.displayUnit ?? "")")
    }

    // MARK: - Shared parts

    /// The icon, with the charging symbol beside it (the icon stays centered).
    private var iconView: some View {
        let badgeSize = max(8, 13 * scale)
        return Image(systemName: icon)
            .font(.system(size: max(9, 18 * scale), weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
            .overlay(alignment: .trailing) {
                chargeBadge
                    .font(.system(size: badgeSize, weight: .bold))
                    .fixedSize()
                    .offset(x: badgeSize + 3 * scale)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.3), value: charge)
            .morph("icon-\(slot.id)", in: morph)
    }

    /// A pulsing green ⚡ while charging, an orange arrow while discharging, nothing when idle.
    @ViewBuilder
    private var chargeBadge: some View {
        switch charge {
        case .charging:
            Image(systemName: "bolt.fill")
                .foregroundStyle(Color(red: 0.20, green: 0.84, blue: 0.29))
                .symbolEffect(.pulse, options: .repeating)
                .accessibilityLabel(L("se încarcă"))
        case .discharging:
            Image(systemName: "arrow.down")
                .foregroundStyle(Color(red: 0.97, green: 0.62, blue: 0.13))
                .accessibilityLabel(L("se descarcă"))
        default:
            EmptyView()
        }
    }

    /// The value: with rollers (if the "Rolling" animation is chosen and the value is numeric) or plain text.
    private func numberView(fontSize: CGFloat, maxWidth: CGFloat) -> some View {
        numberContent(fontSize: fontSize, maxWidth: maxWidth)
            .morph("value-\(slot.id)", in: morph)
    }

    @ViewBuilder
    private func numberContent(fontSize: CGFloat, maxWidth: CGFloat) -> some View {
        let text = entity?.valueText ?? "—"
        if appearance.digitAnimation == .rolling, entity?.numericValue != nil {
            RollingNumberText(text: text, fontSize: fontSize, maxWidth: maxWidth, increasing: increasing)
        } else {
            Self.splitDecimalText(text, fontSize: fontSize)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: maxWidth)
                .contentTransition(.numericText(value: entity?.numericValue ?? 0))
        }
    }

    /// "234.5" → large "234" + ".5" at 60%, on the same baseline (for plain display).
    static func splitDecimalText(_ text: String, fontSize: CGFloat) -> Text {
        let separator = Character(Locale.current.decimalSeparator ?? ",")
        let big = Font.system(size: fontSize, weight: .bold, design: .rounded)
        guard let index = text.firstIndex(of: separator) else { return Text(text).font(big) }
        let small = Font.system(size: fontSize * 0.6, weight: .bold, design: .rounded)
        return Text(text[..<index]).font(big) + Text(text[index...]).font(small)
    }

    /// Approximate width of the unit, subtracted from the space for the value.
    private func unitWidth(fontSize: CGFloat) -> CGFloat {
        guard let unit = entity?.displayUnit else { return 0 }
        return fontSize * 0.62 * CGFloat(unit.count) + 3 * scale
    }

    private func unitText(_ unit: String) -> some View {
        Text(unit)
            .font(.system(size: max(7, 13 * scale), weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
    }

    /// The label sits below the ends of the horseshoe (which reach ~0.37 of the size), in a width
    /// that doesn't touch them. Long text shrinks, then is truncated with "…".
    private var labelView: some View {
        let inHorseshoeGap = slot.displayStyle == .horseshoe || slot.displayStyle == .needle
        return HStack(spacing: 3 * scale) {
            // On the needle gauge the icon sits next to the label, so the needle doesn't cover it.
            if slot.displayStyle == .needle {
                Image(systemName: icon)
                    .morph("icon-\(slot.id)", in: morph)
                chargeBadge
            }
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.65)
        }
        .font(.system(size: max(8, 12 * scale), weight: .semibold))
        .foregroundStyle(.white.opacity(0.75))
        .frame(width: contentSize * (inHorseshoeGap ? 0.6 : 0.8))
        .layoutOffsetY(contentSize * 0.41)
        .animation(.easeInOut(duration: 0.3), value: charge)
    }

    // MARK: - Horseshoe

    /// Icon at the top, value in the middle; the shared label at the bottom, in the horseshoe's gap.
    private var horseshoe: some View {
        ZStack {
            Color.clear.frame(width: contentSize, height: contentSize)
            Group {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                Circle()
                    .trim(from: 0, to: 0.75 * shownFraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .opacity(shownFraction > 0 ? 1 : 0)
            }
            .rotationEffect(.degrees(135))
            .padding(lineWidth / 2) // the arc stays inside its square

            iconView
                .frame(height: contentSize * 0.16)
                .layoutOffsetY(-contentSize * 0.24)

            HStack(alignment: .firstTextBaseline, spacing: 2 * scale) {
                numberView(fontSize: 36 * scale,
                           maxWidth: contentSize * 0.74 - unitWidth(fontSize: max(7, 13 * scale)))
                if let unit = entity?.displayUnit { unitText(unit) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: contentSize * 0.74)
            .layoutOffsetY(contentSize * 0.03)
        }
    }

    // MARK: - Vertical bar

    /// The bar on the left, filling bottom to top; icon, value and unit on the right.
    /// Takes the same area as the horseshoe, above the shared label.
    private var verticalBar: some View {
        let barWidth = contentSize * 0.2
        let barHeight = contentSize * 0.66
        let radius = barWidth * 0.32
        let inset = max(2, 3 * scale)
        return HStack(spacing: contentSize * 0.07) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.white.opacity(0.12))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), lineWidth: max(1, 1.5 * scale))
                RoundedRectangle(cornerRadius: max(1, radius - inset), style: .continuous)
                    .fill(tint.gradient)
                    .frame(height: (barHeight - inset * 2) * shownFraction)
                    .padding(inset)
                    .opacity(shownFraction > 0 ? 1 : 0)
            }
            .frame(width: barWidth, height: barHeight)

            VStack(spacing: 4 * scale) {
                iconView
                numberView(fontSize: 34 * scale, maxWidth: contentSize * 0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                if let unit = entity?.displayUnit {
                    unitText(unit).lineLimit(1)
                }
            }
            .frame(width: contentSize * 0.5)
        }
        .frame(height: barHeight)
        .layoutOffsetY(-contentSize * 0.09)
    }

    // MARK: - Horizontal bar

    /// Icon at the top and value in the middle, as on the horseshoe; below it the bar, filling
    /// left to right; the shared label at the bottom.
    private var horizontalBar: some View {
        let barWidth = contentSize * 0.78
        let barHeight = max(8, contentSize * 0.12)
        let inset = max(2, 2.5 * scale)
        return ZStack {
            Color.clear.frame(width: contentSize, height: contentSize)
            iconView
                .frame(height: contentSize * 0.16)
                .layoutOffsetY(-contentSize * 0.27)

            HStack(alignment: .firstTextBaseline, spacing: 2 * scale) {
                numberView(fontSize: 36 * scale,
                           maxWidth: contentSize * 0.88 - unitWidth(fontSize: max(7, 13 * scale)))
                if let unit = entity?.displayUnit { unitText(unit) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: contentSize * 0.88)
            .layoutOffsetY(-contentSize * 0.05)

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule().strokeBorder(.white.opacity(0.28), lineWidth: max(1, 1.5 * scale))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(barHeight - inset * 2, (barWidth - inset * 2) * shownFraction))
                    .padding(inset)
                    .opacity(shownFraction > 0 ? 1 : 0)
            }
            .frame(width: barWidth, height: barHeight)
            .layoutOffsetY(contentSize * 0.21)
        }
    }

    // MARK: - Text only

    /// No graphic: icon at the top, a large value in the center of the tile, the shared label at the bottom.
    /// Also works for text states (e.g. "Closed", "Eco"), which shrink to fit.
    private var textOnly: some View {
        ZStack {
            Color.clear.frame(width: contentSize, height: contentSize)
            iconView
                .frame(height: contentSize * 0.16)
                .layoutOffsetY(-contentSize * 0.27)

            HStack(alignment: .firstTextBaseline, spacing: 3 * scale) {
                numberView(fontSize: 46 * scale,
                           maxWidth: contentSize * 0.92 - unitWidth(fontSize: max(8, 16 * scale)))
                if let unit = entity?.displayUnit {
                    Text(unit)
                        .font(.system(size: max(8, 16 * scale), weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(width: contentSize * 0.92)
            .layoutOffsetY(contentSize * 0.06)
        }
    }

    // MARK: - Needle gauge

    /// A band in the step colors (red → green) on the same 270° arc.
    private var levelGradient: AngularGradient {
        AngularGradient(colors: Self.levelColors, center: .center,
                        startAngle: .degrees(0), endAngle: .degrees(270))
    }

    /// Short tick labels: 8000 → "8k", 2500 → "2.5k", 237.5 → "237.5".
    static func tickLabel(_ value: Double) -> String {
        if abs(value) >= 1000 {
            return (value / 1000).formatted(.number.precision(.fractionLength(0...1))) + "k"
        }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// Like a speedometer: a colored band, ticks with values between min and max, a needle that
    /// turns smoothly to the current value; the value under the pivot, the shared label at the bottom.
    private var needleGauge: some View {
        let side = contentSize
        let band = max(3, 5 * scale)
        let radius = side / 2 - band / 2
        let tickOuter = radius - band / 2 - max(1, 1.5 * scale)
        let majorLength = side * 0.06
        let minorLength = side * 0.03
        let needleLength = tickOuter - side * 0.03
        // The center disc: as large as possible, but inside the tick labels (which start around 0.28 of the size).
        let discDiameter = side * 0.55
        let angle = Angle.degrees(135 + 270 * shownFraction)
        // On small tiles only min, middle and max are labeled, to avoid clutter.
        // Labels only at min, middle and max: the ones at 25% / 75% would end up under the center disc.
        let labeledSteps: Set<Int> = [0, 10, 20]
        let range = self.range

        return ZStack {
            Color.clear.frame(width: side, height: side)
            Group {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(levelGradient, style: StrokeStyle(lineWidth: band, lineCap: .butt))
                    .opacity(0.28)
                Circle()
                    .trim(from: 0, to: 0.75 * shownFraction)
                    .stroke(levelGradient, style: StrokeStyle(lineWidth: band, lineCap: .butt))
                    .opacity(fraction == nil ? 0 : 1)
            }
            .rotationEffect(.degrees(135))
            .padding(band / 2)

            // Ticks: major at 0/25/50/75/100%, minor every 5%.
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                for step in 0...20 {
                    let isMajor = step % 5 == 0
                    let radians = (135 + 270 * Double(step) / 20) * .pi / 180
                    let direction = CGVector(dx: cos(radians), dy: sin(radians))
                    let outer = CGPoint(x: center.x + direction.dx * tickOuter,
                                        y: center.y + direction.dy * tickOuter)
                    let innerRadius = tickOuter - (isMajor ? majorLength : minorLength)
                    let inner = CGPoint(x: center.x + direction.dx * innerRadius,
                                        y: center.y + direction.dy * innerRadius)
                    var tick = Path()
                    tick.move(to: outer)
                    tick.addLine(to: inner)
                    context.stroke(tick,
                                   with: .color(.white.opacity(isMajor ? 0.85 : 0.4)),
                                   lineWidth: isMajor ? max(1, 1.5 * scale) : max(0.5, 1 * scale))
                    if let range, labeledSteps.contains(step) {
                        let value = range.min + (range.max - range.min) * Double(step) / 20
                        let position: CGPoint
                        if step == 10 {
                            // Middle: at the top, under its tick.
                            let labelRadius = innerRadius - side * 0.058
                            position = CGPoint(x: center.x + direction.dx * labelRadius,
                                               y: center.y + direction.dy * labelRadius)
                        } else {
                            // Min and max: under the ends of the arc, in the bottom gap.
                            position = CGPoint(x: center.x + direction.dx * radius,
                                               y: center.y + direction.dy * radius + side * 0.085)
                        }
                        context.draw(
                            Text(Self.tickLabel(value))
                                .font(.system(size: max(6, 8.5 * scale), weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7)),
                            at: position, anchor: .center)
                    }
                }
            }
            .frame(width: side, height: side)

            // The needle is anchored at the center: the capsule is shifted right by half its length,
            // then rotated around the tile's center. Its inner part is hidden under the disc.
            Capsule()
                .fill(.white)
                .frame(width: needleLength, height: max(2, 2.5 * scale))
                .offset(x: needleLength / 2)
                .rotationEffect(angle)
                .shadow(color: .black.opacity(0.6), radius: 1.5)
                .opacity(fraction == nil ? 0 : 1)

            // Opaque center disc, like on older Mercedes dashboards: it covers the needle pivot and
            // leaves room for the value in the middle, without touching the ticks or their labels.
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.17), Color(white: 0.05)],
                                     center: .center, startRadius: 0, endRadius: discDiameter / 2))
                .overlay {
                    Circle().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.12)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: max(1, 1.5 * scale))
                }
                .shadow(color: .black.opacity(0.7), radius: 3 * scale)
                .frame(width: discDiameter, height: discDiameter)

            VStack(spacing: 0) {
                numberView(fontSize: 30 * scale, maxWidth: discDiameter * 0.82)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let unit = entity?.displayUnit {
                    Text(unit)
                        .font(.system(size: max(7, 11 * scale), weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .frame(width: discDiameter * 0.86)
        }
    }
}

extension View {
    /// Moves vertically through layout (an alignment guide), not a visual transform, so
    /// matchedGeometryEffect sees the element's real position.
    func layoutOffsetY(_ y: CGFloat) -> some View {
        alignmentGuide(VerticalAlignment.center) { dimensions in
            dimensions[VerticalAlignment.center] - y
        }
    }

    /// Links the element to its twin on the collapsed island: when opening/closing only the position
    /// animates between the two (the size cross-fades), so the text doesn't get torn.
    @ViewBuilder
    func morph(_ id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedGeometryEffect(id: id, in: namespace, properties: .position)
        } else {
            self
        }
    }
}
