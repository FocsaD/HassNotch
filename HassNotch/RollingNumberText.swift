import SwiftUI

/// A number shown with rollers, like old fuel pumps: each digit is a 0–9 roller that
/// turns through the digits in between. When the value goes up the rollers roll forward
/// (8 → 9 → 0 → 1), when it goes down they roll back. Separators and the minus sign stay put.
struct RollingNumberText: View {
    let text: String
    let fontSize: CGFloat
    /// The available width; the font shrinks if the number doesn't fit.
    let maxWidth: CGFloat
    let increasing: Bool
    /// Decimals (and the decimal separator) are smaller, so the integer part can be large.
    var fractionScale: CGFloat = 0.6

    private struct Glyph: Identifiable {
        let id: String
        let character: Character
        /// Belongs to the decimals (the separator or the digits after it).
        let isFraction: Bool
    }

    /// Each character gets an identity from its position relative to the decimal separator: the units
    /// stay the same roller even when the number goes from 998 to 1,002 (the new roller appears on the left).
    private var glyphs: [Glyph] {
        let separator = Character(Locale.current.decimalSeparator ?? ",")
        let characters = Array(text)
        let decimalIndex = characters.firstIndex(of: separator) ?? characters.count
        return characters.enumerated().map { index, character in
            let position: String
            if character == "-" || character == "−" {
                position = "minus"
            } else if index < decimalIndex {
                position = "i\(decimalIndex - 1 - index)"
            } else if index == decimalIndex {
                position = "dec"
            } else {
                position = "f\(index - decimalIndex - 1)"
            }
            return Glyph(id: position + (Self.digit(character) != nil ? "d" : "s"),
                         character: character,
                         isFraction: index >= decimalIndex && position != "minus")
        }
    }

    private static func digit(_ character: Character) -> Int? {
        guard character.isASCII, let value = character.wholeNumberValue else { return nil }
        return value
    }

    /// Width estimate: monospaced digits ~0.62 of the font size, separators ~0.32;
    /// decimals count for less because they are smaller.
    private var fittedSize: CGFloat {
        let ems = glyphs.reduce(0.0) { total, glyph in
            let width: CGFloat = Self.digit(glyph.character) != nil ? 0.62 : 0.32
            return total + width * (glyph.isFraction ? fractionScale : 1)
        }
        guard ems > 0, maxWidth > 0 else { return fontSize }
        return min(fontSize, maxWidth / ems)
    }

    var body: some View {
        let size = fittedSize
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(glyphs) { glyph in
                let font = Font.system(size: glyph.isFraction ? size * fractionScale : size,
                                       weight: .bold, design: .rounded).monospacedDigit()
                Group {
                    if let digit = Self.digit(glyph.character) {
                        DigitRoller(digit: digit, increasing: increasing, font: font)
                    } else {
                        Text(String(glyph.character)).font(font)
                    }
                }
                .transition(.opacity)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// A single roller: a column with the digits 0–9 repeated 3 times, showing one digit.
private struct DigitRoller: View {
    let digit: Int
    let increasing: Bool
    let font: Font

    private static let cycles = 3
    /// Position in the column (0…29). At rest it stays in the middle cycle (10…19).
    @State private var position: Int?
    @State private var settleTask: Task<Void, Never>?

    private var shownPosition: Int { position ?? 10 + digit }

    var body: some View {
        Text("0")
            .font(font)
            .hidden()
            .overlay(alignment: .top) {
                GeometryReader { geometry in
                    let height = geometry.size.height
                    VStack(spacing: 0) {
                        ForEach(0..<(Self.cycles * 10), id: \.self) { index in
                            Text("\(index % 10)")
                                .font(font)
                                .frame(width: geometry.size.width, height: height)
                        }
                    }
                    .offset(y: -CGFloat(shownPosition) * height)
                }
            }
            .clipped()
            .onChange(of: digit) { old, new in roll(from: old, to: new) }
    }

    private func roll(from old: Int, to new: Int) {
        var start = shownPosition
        let steps = increasing ? (new - old + 10) % 10 : -((old - new + 10) % 10)
        // If we'd leave the column (very fast changes), jump to the middle cycle without animation.
        if start + steps < 0 || start + steps >= Self.cycles * 10 {
            start = 10 + old
            var snap = Transaction()
            snap.disablesAnimations = true
            withTransaction(snap) { position = start }
        }
        withAnimation(EntityGauge.valueAnimation) { position = start + steps }
        // After the animation, quietly return to the middle cycle to leave room for the next turn.
        settleTask?.cancel()
        settleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            var settle = Transaction()
            settle.disablesAnimations = true
            withTransaction(settle) { position = 10 + digit }
        }
    }
}
