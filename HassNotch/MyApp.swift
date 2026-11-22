
import SwiftUI
import AppKit
import Combine

@main
struct HassNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate
    /// The menu bar menu redraws when the language changes.
    @ObservedObject private var notchSettings = NotchSettings.shared

    var body: some Scene {
        MenuBarExtra("HassNotch", systemImage: "rectangle.topthird.inset.filled") {
            Button(L("Setări…")) { appDelegate.showSettings() }
                .keyboardShortcut(",")
            Button(L("Informații afișate…")) { appDelegate.showDisplaySettings() }
            Divider()
            Button(L("Închide HassNotch")) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NSPanel?
    private let notchHover = NotchHoverController()
    private var settingsWindow: NSWindow?
    private let settingsNavigation = SettingsNavigation()
    private var styleObserver: AnyCancellable?
    private var positionObserver: AnyCancellable?
    private var languageObserver: AnyCancellable?
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only, or also in the Dock, as chosen in Settings.
        NSApp.setActivationPolicy(NotchSettings.shared.showInDock ? .regular : .accessory)
        showNotch()
        // When the notch type changes in Settings, rebuild the island.
        styleObserver = NotchSettings.shared.$style
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] style in
                MainActor.assumeIsolated { self?.showNotch(style: style) }
            }
        // The Dynamic Island position updates live from Settings → Position.
        let settings = NotchSettings.shared
        positionObserver = Publishers.CombineLatest3(settings.$islandOffsetX, settings.$islandOffsetY,
                                                     settings.$islandScreenID)
            .dropFirst()
            .debounce(for: .milliseconds(30), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.showNotch() }
            }
        // The settings window title follows the chosen language.
        languageObserver = settings.$language
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.settingsWindow?.title = L("Setări · HassNotch") }
            }
        // Display connected / disconnected / resolution changed: reposition the island.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.showNotch() }
        }
        if HomeAssistantManager.shared.isConfigured {
            // The real-time connection starts right away and reconnects by itself if the network isn't ready.
            HomeAssistantManager.shared.startLive()
            Task {
                await HomeAssistantManager.shared.connect()
                if HomeAssistantManager.shared.displayed.allSatisfy({ $0.entityID.isEmpty }) {
                    showDisplaySettings()
                }
            }
        } else {
            showSettings()
        }
    }

    /// Opens the settings window, optionally on a specific category.
    func showSettings(tab: SettingsTab = .connection) {
        settingsNavigation.selection = tab
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 580),
                                  styleMask: [.titled, .closable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = L("Setări · HassNotch")
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsWindowView(navigation: settingsNavigation))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func showDisplaySettings() {
        showSettings(tab: .display)
    }

    private func showNotch(style requestedStyle: NotchStyle? = nil) {
        let style = requestedStyle ?? NotchSettings.shared.style
        notchWindow?.orderOut(nil)
        notchWindow = nil
        // The island goes on the display chosen in Settings → Display (main display by default).
        guard let screen = NotchSettings.shared.islandScreen else { return }

        let collapsedSize: CGSize
        let expandedWidth: CGFloat
        let topGap: CGFloat      // gap between the screen edge and the shape
        let contentTop: CGFloat  // where the gauges start when expanded

        switch style {
        case .notch:
            let topInset = max(34, screen.safeAreaInsets.top)
            let hardwareWidth: CGFloat
            if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
                hardwareWidth = screen.frame.width - left.width - right.width
            } else {
                hardwareWidth = 190
            }
            let collapsedWidth = max(190, hardwareWidth)
            collapsedSize = CGSize(width: collapsedWidth, height: topInset)
            expandedWidth = max(460, collapsedWidth + 2 * NotchView.wing + 40)
            topGap = 0
            contentTop = topInset + 14
        case .island:
            // The pill is as tall as the menu bar, with 2 pt of air above and below.
            let menuBarHeight = max(22, screen.frame.maxY - screen.visibleFrame.maxY,
                                    NSStatusBar.system.thickness)
            topGap = 2
            // Fixed width, chosen to fit 3 values with icons; it doesn't change without hover.
            collapsedSize = CGSize(width: 168, height: menuBarHeight - topGap * 2)
            expandedWidth = NotchView.islandWindowWidth
            contentTop = 16
        }

        // The window has the maximum size (all entities); the black shape only grows as needed.
        let width = expandedWidth
        let height = topGap + NotchLayout.maxExpandedHeight(width: expandedWidth, contentTop: contentTop)
        // The user-chosen position (Dynamic Island only), clamped so the island stays on screen.
        let maxOffsetX = max(0, screen.frame.width / 2 - width / 2)
        let offsetX = style == .island
            ? min(max(CGFloat(NotchSettings.shared.islandOffsetX), -maxOffsetX), maxOffsetX) : 0
        let offsetY = style == .island ? max(0, CGFloat(NotchSettings.shared.islandOffsetY)) : 0
        let x = screen.frame.midX - width / 2 + offsetX
        let y = screen.frame.maxY - height - offsetY

        let window = EdgePanel(
            contentRect: NSRect(x: x.rounded(), y: y, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]

        // The window lets clicks pass through to the apps below;
        // it only receives them while the island is expanded.
        window.ignoresMouseEvents = true
        window.acceptsMouseMovedEvents = true
        window.hidesOnDeactivate = false

        window.contentView = NSHostingView(
            rootView: NotchView(hover: notchHover, style: style,
                                collapsedSize: collapsedSize, expandedWidth: expandedWidth,
                                topGap: topGap, contentTop: contentTop,
                                onOpenSettings: { [weak self] in self?.showSettings() })
                .ignoresSafeArea()
        )

        window.orderFrontRegardless()
        notchWindow = window

        // The area that opens the island: the collapsed shape, including the space up to the screen edge.
        // On the notch, the shape widens outward while always-visible values are shown.
        let screenFrame = screen.frame
        let collapsedRect: () -> NSRect = {
            let manager = HomeAssistantManager.shared
            let size = NotchView.collapsedShapeSize(style: style, base: collapsedSize,
                                                    displayed: manager.displayed,
                                                    hasNotification: manager.currentNotification != nil,
                                                    attention: manager.notificationAttention)
            return NSRect(x: screenFrame.midX + offsetX - size.width / 2,
                          y: screenFrame.maxY - offsetY - topGap - size.height,
                          width: size.width,
                          height: size.height + topGap)
        }
        // The expanded area follows the shape's real height, which depends on the number of entities.
        let frame = window.frame
        notchHover.start(window: window, collapsedRect: collapsedRect, expandedRect: {
            let shapeHeight = NotchLayout(count: HomeAssistantManager.shared.displayed.count, width: expandedWidth)
                .expandedHeight(contentTop: contentTop)
            return NSRect(x: frame.minX, y: frame.maxY - topGap - shapeHeight,
                          width: frame.width, height: shapeHeight + topGap)
        })
    }
}

// Tracks the mouse position globally and decides when the island expands.
// The window only receives clicks when expanded, so it doesn't block the windows below.
@MainActor
final class NotchHoverController: ObservableObject {
    @Published private(set) var isExpanded = false
    private weak var window: NSWindow?
    private var collapsedRect: () -> NSRect = { .zero }
    private var expandedRect: () -> NSRect = { .zero }
    private var monitors: [Any] = []
    private var hapticPending = false
    /// Incremented on every haptic tap.
    @Published private(set) var hapticTick = 0

    /// The opening haptic, played once, from the island window's mouse event.
    func performPendingHaptic() {
        guard hapticPending else { return }
        hapticPending = false
        hapticTick += 1
        Haptics.tap()
    }

    func start(window: NSWindow, collapsedRect: @escaping () -> NSRect, expandedRect: @escaping () -> NSRect) {
        self.window = window
        isExpanded = false
        self.collapsedRect = collapsedRect
        self.expandedRect = expandedRect
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.update() }
            return event
        }) { monitors.append(local) }
    }

    private func update() {
        let point = NSEvent.mouseLocation
        // The 2 px margin also catches a cursor pressed against the top edge of the screen.
        let zone = (isExpanded ? expandedRect() : collapsedRect()).insetBy(dx: 0, dy: -2)
        let inside = zone.contains(point)
        guard inside != isExpanded else { return }
        window?.ignoresMouseEvents = !inside
        // A subtle trackpad "click" when the island opens, like other notch apps.
        // macOS only delivers haptics to the app handling the current trackpad event.
        // So it is kept "pending" and played from the first mouse event received by
        // the island window itself (HapticTrackingView); fallback: play it anyway after 0.2 s.
        hapticPending = inside && NotchSettings.shared.hapticsEnabled
        if hapticPending {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.performPendingHaptic()
            }
        }
        // Closing is slower, so you can see the digits "fly" back to their spot on the collapsed island.
        let animation: Animation = inside
            ? .spring(response: 0.5, dampingFraction: 0.8)
            : .spring(response: 0.8, dampingFraction: 0.88)
        withAnimation(animation) {
            isExpanded = inside
        }
    }
}

struct NotchView: View {
    @ObservedObject var hover: NotchHoverController
    /// The island's texts follow the language.
    @ObservedObject private var notchSettings = NotchSettings.shared
    /// Digits and icons move smoothly between the expanded and collapsed island.
    @Namespace private var morphSpace
    @ObservedObject private var manager = HomeAssistantManager.shared

    let style: NotchStyle
    let collapsedSize: CGSize
    let expandedWidth: CGFloat
    let topGap: CGFloat
    let contentTop: CGFloat
    var onOpenSettings: () -> Void
    private var isExpanded: Bool { hover.isExpanded }

    // MARK: - Values on the collapsed island

    /// The width of each "wing" added on either side of the hardware notch.
    static let wing: CGFloat = 58

    /// How many values fit on the collapsed island: 3 on Dynamic Island, 2 on the notch (one per side).
    static func maxCollapsed(_ style: NotchStyle) -> Int { style == .notch ? 2 : 3 }

    /// Entities marked "always show", in list order, as many as fit.
    static func collapsedSlots(_ displayed: [DisplayedEntity], style: NotchStyle) -> [DisplayedEntity] {
        Array(CollapsedPosition.layout(displayed, style: style).values)
    }

    /// Dynamic Island keeps its width; the notch only widens when it has something to show.
    static func collapsedWidth(style: NotchStyle, base: CGFloat, displayed: [DisplayedEntity]) -> CGFloat {
        guard style == .notch, !collapsedSlots(displayed, style: style).isEmpty else { return base }
        return base + 2 * wing
    }

    /// Width of the Dynamic Island window (expanded island).
    static let islandWindowWidth: CGFloat = 460

    /// How far the notch grows down for the notification row.
    static let notchBannerHeight: CGFloat = 26

    /// Size of the collapsed island. On a notification: Dynamic Island doubles its width,
    /// the notch grows down by one row.
    /// For a few seconds after a notification arrives: Dynamic Island grows 2.2× vertically,
    /// and on the notch the notification row gets taller.
    static let islandAttentionScale: CGFloat = 2.2
    static let notchAttentionBannerHeight: CGFloat = 46

    static func collapsedShapeSize(style: NotchStyle, base: CGSize, displayed: [DisplayedEntity],
                                   hasNotification: Bool, attention: Bool = false) -> CGSize {
        let width = collapsedWidth(style: style, base: base.width, displayed: displayed)
        guard hasNotification else { return CGSize(width: width, height: base.height) }
        switch style {
        case .island:
            return CGSize(width: base.width * 2,
                          height: attention ? base.height * islandAttentionScale : base.height)
        case .notch:
            return CGSize(width: max(width, 260),
                          height: base.height + (attention ? notchAttentionBannerHeight : notchBannerHeight))
        }
    }

    private var collapsedSlots: [DisplayedEntity] { Self.collapsedSlots(manager.displayed, style: style) }
    private var showsNotification: Bool {
        manager.currentNotification != nil && NotchSettings.shared.notificationsEnabled
    }
    private var attention: Bool { showsNotification && manager.notificationAttention }
    private var collapsedShape: CGSize {
        Self.collapsedShapeSize(style: style, base: collapsedSize, displayed: manager.displayed,
                                hasNotification: showsNotification, attention: attention)
    }
    private var collapsedWidth: CGFloat { collapsedShape.width }

    /// The notification on the collapsed island: a bell + text that scrolls if it doesn't fit.
    private func notificationBanner(_ notification: NotchNotification, width: CGFloat, fontSize: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "bell.fill")
                .font(.system(size: fontSize * 0.9, weight: .semibold))
                .foregroundStyle(.orange)
            MarqueeText(text: notification.text,
                        font: .system(size: fontSize, weight: .semibold, design: .rounded),
                        width: width - fontSize * 1.6)
        }
        .frame(width: width)
        .id(notification.id)
    }

    private func collapsedValue(_ slot: DisplayedEntity?, width: CGFloat) -> some View {
        Group {
            if let slot {
                let entity = manager.entity(slot.entityID)
                CollapsedValueView(entity: entity,
                                   icon: slot.icon.isEmpty ? EntityIcons.automatic(for: entity) : slot.icon,
                                   slotID: slot.id,
                                   morph: morphSpace,
                                   fontSize: style == .notch ? 12 : max(8, collapsedSize.height * 0.46),
                                   maxWidth: width)
            } else {
                Color.clear
            }
        }
        .frame(width: width)
    }

    /// Each value sits in its chosen slot (left / middle / right); empty slots stay empty.
    @ViewBuilder
    private var collapsedContent: some View {
        let layout = CollapsedPosition.layout(manager.displayed, style: style)
        switch style {
        case .island:
            let third = (collapsedSize.width - 16) / 3
            HStack(spacing: 0) {
                collapsedValue(layout[.left], width: third)
                collapsedValue(layout[.center], width: third)
                collapsedValue(layout[.right], width: third)
            }
            .padding(.horizontal, 8)
        case .notch:
            HStack(spacing: 0) {
                collapsedValue(layout[.left], width: Self.wing - 8)
                Spacer(minLength: 0)
                collapsedValue(layout[.right], width: Self.wing - 8)
            }
            .padding(.horizontal, 4)
        }
    }

    private var layout: NotchLayout { NotchLayout(count: manager.displayed.count, width: expandedWidth) }
    private var expandedHeight: CGFloat { layout.expandedHeight(contentTop: contentTop) }

    /// The grid rows: entities split into groups of `layout.columns`.
    private var rows: [[DisplayedEntity]] {
        stride(from: 0, to: manager.displayed.count, by: layout.columns).map {
            Array(manager.displayed[$0..<min($0 + layout.columns, manager.displayed.count)])
        }
    }

    /// Classic notch: rounded corners only at the bottom. Dynamic Island: fully rounded pill.
    private var shape: UnevenRoundedRectangle {
        switch style {
        case .notch:
            let radius: CGFloat = isExpanded ? 24 : 12
            return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: radius,
                                          bottomTrailingRadius: radius, topTrailingRadius: 0,
                                          style: .continuous)
        case .island:
            // Stays a capsule even when it grows for a notification.
            let radius: CGFloat = isExpanded ? 30 : collapsedShape.height / 2
            return UnevenRoundedRectangle(topLeadingRadius: radius, bottomLeadingRadius: radius,
                                          bottomTrailingRadius: radius, topTrailingRadius: radius,
                                          style: .continuous)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            shape
            .fill(.black)
            .frame(
                width: isExpanded ? expandedWidth : collapsedWidth,
                height: isExpanded ? expandedHeight : collapsedShape.height
            )
            .overlay(alignment: .top) {
                if isExpanded {
                    Group {
                        if manager.displayed.isEmpty {
                            Label(L("Apasă rotița ca să alegi ce se afișează"), systemImage: "plus.circle")
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(height: layout.cell)
                        } else {
                            VStack(spacing: NotchLayout.spacing) {
                                ForEach(rows.indices, id: \.self) { index in
                                    HStack(spacing: NotchLayout.spacing) {
                                        ForEach(rows[index]) { slot in
                                            EntityGauge(slot: slot, entity: manager.entity(slot.entityID),
                                                        range: manager.range(for: slot)?.range,
                                                        size: layout.cell,
                                                        charge: manager.chargeState(for: slot),
                                                        morph: morphSpace)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, contentTop)
                    .foregroundStyle(.white)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if isExpanded {
                    ConnectionStatusView(connected: manager.liveConnected || manager.readingsAvailable)
                        // On the same line as the center of the gear on the right.
                        .padding(.bottom, style == .island ? 21 : 17)
                        .padding(.leading, style == .island ? 22 : 18)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isExpanded {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 28, height: 28)
                            .background(.white.opacity(0.1), in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(L("Setări"))
                    .accessibilityLabel(L("Setări"))
                    .padding(.bottom, style == .island ? 14 : 10)
                    .padding(.trailing, style == .island ? 18 : 14)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .top) {
                // On Dynamic Island the notification replaces the values; on the notch the values stay in the wings.
                if !isExpanded && !collapsedSlots.isEmpty && !(showsNotification && style == .island) {
                    collapsedContent
                        .frame(height: collapsedSize.height)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: style == .island ? .center : .bottom) {
                if !isExpanded, showsNotification, let notification = manager.currentNotification {
                    Group {
                        switch style {
                        case .island:
                            notificationBanner(notification, width: collapsedShape.width - 24,
                                               fontSize: max(9, collapsedSize.height * (attention ? 0.85 : 0.5)))
                        case .notch:
                            notificationBanner(notification, width: collapsedShape.width - 28,
                                               fontSize: attention ? 16 : 12)
                                .frame(height: attention ? Self.notchAttentionBannerHeight : Self.notchBannerHeight)
                        }
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }
            .clipShape(shape)
            .padding(.top, topGap)

            Spacer(minLength: 0)
        }
        .background(HapticTrackingView(hover: hover))
        .frame(
            width: expandedWidth,
            height: topGap + NotchLayout.maxExpandedHeight(width: expandedWidth, contentTop: contentTop),
            alignment: .top
        )
        .task {
            while !Task.isCancelled {
                // With the real-time connection active, periodic polling isn't needed.
                if !manager.liveConnected { await manager.refreshEntities() }
                do { try await Task.sleep(for: .seconds(30)) } catch { break }
            }
        }
    }
}

/// Status dot, like the macOS camera/microphone indicators: green while data is arriving
/// from Home Assistant, red when it isn't.
struct ConnectionStatusView: View {
    let connected: Bool

    private var color: Color {
        connected ? Color(red: 0.20, green: 0.84, blue: 0.29) : Color(red: 1.0, green: 0.27, blue: 0.23)
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.8), radius: 3)
            Text(connected ? L("Conectat la HA") : L("Neconectat la HA"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .animation(.easeInOut(duration: 0.3), value: connected)
        .accessibilityElement(children: .combine)
    }
}

/// A small value on the collapsed island: just the digits, with rollers or a plain change,
/// depending on the "Digit animation" setting.
struct CollapsedValueView: View {
    let entity: HAEntity?
    let icon: String
    let slotID: UUID
    let morph: Namespace.ID?
    let fontSize: CGFloat
    let maxWidth: CGFloat

    @ObservedObject private var appearance = NotchSettings.shared
    @State private var lastValue: Double?

    private var increasing: Bool {
        guard let new = entity?.numericValue, let old = lastValue else { return true }
        return new >= old
    }

    /// For batteries (device class "battery" or "battery/baterie/soc" in the name) a "%" follows the digits.
    private var showsPercent: Bool {
        guard let entity, entity.numericValue != nil, entity.attributes.unit_of_measurement == "%" else { return false }
        if entity.attributes.device_class == "battery" { return true }
        let text = (entity.entity_id + " " + entity.name).lowercased()
        return ["batter", "baterie", "soc", "state_of_charge"].contains { text.contains($0) }
    }

    var body: some View {
        let text = entity?.valueText ?? "—"
        let iconWidth = fontSize * 1.1
        let spacing = fontSize * 0.25
        let percentWidth = showsPercent ? fontSize * 0.75 : 0
        let digitsWidth = maxWidth - iconWidth - spacing - percentWidth
        HStack(spacing: spacing) {
            Image(systemName: icon)
                .font(.system(size: fontSize * 0.9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: iconWidth)
                .morph("icon-\(slotID)", in: morph)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                digits(text, maxWidth: digitsWidth)
                    .morph("value-\(slotID)", in: morph)
                if showsPercent {
                    Text("%")
                        .font(.system(size: fontSize * 0.72, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .foregroundStyle(.white)
        .frame(width: maxWidth)
        .animation(EntityGauge.valueAnimation, value: entity?.valueText)
        .onAppear { lastValue = entity?.numericValue }
        .onChange(of: entity?.numericValue) { _, new in lastValue = new }
    }

    @ViewBuilder
    private func digits(_ text: String, maxWidth: CGFloat) -> some View {
        Group {
            if appearance.digitAnimation == .rolling, entity?.numericValue != nil {
                RollingNumberText(text: text, fontSize: fontSize, maxWidth: maxWidth, increasing: increasing)
            } else {
                EntityGauge.splitDecimalText(text, fontSize: fontSize)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText(value: entity?.numericValue ?? 0))
            }
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
    }
}

/// Catches the first mouse event in the island window (once it starts receiving
/// the mouse) and plays the opening haptic from it. Doesn't block clicks: hitTest = nil.
private struct HapticTrackingView: NSViewRepresentable {
    let hover: NotchHoverController

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.hover = hover
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) {
        view.hover = hover
    }

    final class TrackingView: NSView {
        weak var hover: NotchHoverController?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: .zero,
                                           options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                           owner: self, userInfo: nil))
        }

        override func mouseEntered(with event: NSEvent) { hover?.performPendingHaptic() }
        override func mouseMoved(with event: NSEvent) { hover?.performPendingHaptic() }
    }
}

/// A panel without frame constraints: macOS no longer pushes it below the top edge of the screen,
/// so the notch starts at the very first pixel, with no thin line above it.
final class EdgePanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
