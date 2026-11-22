import SwiftUI

/// Display-style picker with thumbnails: each one is drawn with the same code as
/// the gauge on the island, on a black background, with a sample value (65%).
struct DisplayStylePicker: View {
    @Binding var style: EntityDisplayStyle
    /// The row's icon, so the thumbnails look like what you will actually see.
    var icon: String = "house.fill"

    private static let sample = HAEntity(id: "sensor.preview",
                                         raw: ["state": "65",
                                               "attributes": ["unit_of_measurement": "%"]])

    var body: some View {
        HStack(spacing: 8) {
            ForEach(EntityDisplayStyle.allCases) { option in
                Button { style = option } label: {
                    VStack(spacing: 4) {
                        EntityGauge(slot: DisplayedEntity(label: L("Exemplu"), icon: icon, style: option),
                                    entity: Self.sample,
                                    range: GaugeRange(min: 0, max: 100),
                                    size: 64)
                            .foregroundStyle(.white)
                            .environment(\.colorScheme, .dark)
                            .padding(4)
                            .background(.black, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(option == style ? Color.accentColor : .clear, lineWidth: 2)
                            }
                            .allowsHitTesting(false)
                        Text(option.title)
                            .font(.caption2)
                            .foregroundStyle(option == style ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(width: 80)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(option.title)
                .accessibilityAddTraits(option == style ? .isSelected : [])
            }
        }
    }
}
