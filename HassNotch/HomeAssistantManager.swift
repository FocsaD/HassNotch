import Foundation
import AppKit
import Security
import Combine
import SwiftUI

// Never forward the credential to a redirected destination.
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
final class HomeAssistantManager: ObservableObject {
    static let shared = HomeAssistantManager()
    @Published private(set) var connected = false
    @Published private(set) var isConnecting = false
    @Published private(set) var status = L("Configurează conexiunea la casa ta.")
    @Published private(set) var serverURL: String
    @Published private(set) var homeName = "Home Assistant"
    @Published private(set) var version = ""
    @Published private(set) var lastChecked: Date?
    @Published private(set) var hasSavedToken = false
    @Published private(set) var entities: [HAEntity] = [] {
        didSet { recordTrends(from: oldValue) }
    }
    @Published private(set) var readingsAvailable = false
    @Published private(set) var readingsStatus = L("Se încarcă senzorii…")
    @Published private(set) var readingsUpdated: Date?
    @Published private(set) var refreshing = false
    /// The entities shown on the island, in order.
    @Published var displayed: [DisplayedEntity] = HomeAssistantManager.loadDisplayed() {
        didSet {
            if let data = try? JSONEncoder().encode(displayed) {
                UserDefaults.standard.set(data, forKey: "displayedEntities")
            }
            // A different entity list → resubscribe in real time to the new ones only.
            if liveEntityIDs != liveSubscribedIDs { startLive() }
        }
    }
    /// The entities that can be chosen for display.
    var displayCandidates: [HAEntity] {
        let domains = ["sensor.", "binary_sensor.", "number.", "input_number."]
        return entities.filter { entity in domains.contains { entity.entity_id.hasPrefix($0) } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    func entity(_ id: String) -> HAEntity? {
        guard readingsAvailable, !id.isEmpty else { return nil }
        return entities.first { $0.entity_id == id }
    }
    /// Ranges found in Gauge cards on Home Assistant dashboards, per entity.
    @Published private(set) var dashboardRanges: [String: GaugeRange] = {
        guard let data = UserDefaults.standard.data(forKey: "dashboardRanges"),
              let saved = try? JSONDecoder().decode([String: GaugeRange].self, from: data) else { return [:] }
        return saved
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(dashboardRanges) {
                UserDefaults.standard.set(data, forKey: "dashboardRanges")
            }
        }
    }
    @Published private(set) var rangesStatus = ""
    @Published private(set) var loadingRanges = false

    /// A gauge's range: manual → HA Gauge card → entity min/max → percentage.
    func range(for slot: DisplayedEntity) -> (range: GaugeRange, source: GaugeRangeSource)? {
        if let min = slot.minValue, let max = slot.maxValue, max > min {
            return (GaugeRange(min: min, max: max), .manual)
        }
        if let range = dashboardRanges[slot.entityID] {
            return (range, .dashboard)
        }
        let entity = entities.first { $0.entity_id == slot.entityID }
        if let min = entity?.attributes.min, let max = entity?.attributes.max, max > min {
            return (GaugeRange(min: min, max: max), .entity)
        }
        if entity?.attributes.unit_of_measurement == "%" {
            return (GaugeRange(min: 0, max: 100), .percent)
        }
        return nil
    }

    // MARK: - Real time (WebSocket)

    /// The real-time connection is active and updates arrive instantly.
    @Published private(set) var liveConnected = false
    private var liveTask: Task<Void, Never>?
    private var liveSubscribedIDs: Set<String> = []
    /// The latest state received over the WebSocket, per entity: {"state": …, "attributes": {…}}.
    private var liveRaw: [String: [String: Any]] = [:]
    private var pendingLive: Set<String> = []
    private var flushScheduled = false
    private var liveLastMessage = Date()
    private var wakeObserver: NSObjectProtocol?

    /// A separate session: the connection stays open indefinitely, with a ping every 25 seconds.
    private lazy var liveSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 60 * 60 * 24 * 7
        return URLSession(configuration: config, delegate: redirectDelegate, delegateQueue: nil)
    }()

    private var liveEntityIDs: Set<String> {
        var ids = displayed.map(\.entityID)
        // Sensors used for the charging state must be followed in real time too.
        ids += displayed.compactMap { slot in
            slot.chargeEnabled == true && (slot.chargeSource ?? .automatic) != .automatic
                ? slot.chargeEntityID : nil
        }
        return Set(ids.filter { !$0.isEmpty })
    }

    // MARK: - Language

    /// After the language changes, the status messages shown are rewritten in the new language.
    func relocalizeStatuses() {
        if liveConnected {
            readingsStatus = L("În timp real · %@ entități urmărite", liveSubscribedIDs.count)
        } else if readingsAvailable {
            readingsStatus = L("%@ entități citite din Home Assistant", entities.count)
        } else {
            readingsStatus = L("Se încarcă senzorii…")
        }
        if connected {
            status = L("Conexiune verificată. Configurarea a fost salvată.")
        } else if !isConfigured {
            status = L("Configurează conexiunea la casa ta.")
        }
        rangesStatus = ""
        notificationsStatus = liveConnected && NotchSettings.shared.notificationsEnabled
            ? L("Ascult notificările din Home Assistant.") : ""
    }

    // MARK: - Notifications

    @Published private(set) var currentNotification: NotchNotification?
    /// The first ~3.5 seconds of a notification: the island is also enlarged vertically.
    @Published private(set) var notificationAttention = false
    @Published private(set) var recentNotifications: [NotchNotification] = []
    @Published private(set) var notificationsStatus = ""
    private var notificationQueue: [NotchNotification] = []
    private var lastNotificationKey: (key: String, at: Date)?

    /// Command messages for the HA mobile app (not meant for humans).
    private static let commandMessages: Set<String> = [
        "clear_notification", "request_location_update", "remove_channel", "TTS",
        "update_sensors", "update_widgets", "update_complications", "clear_badge"
    ]

    private func handleServiceCall(_ data: [String: Any]) {
        guard data["domain"] as? String == "notify", let service = data["service"] as? String else { return }
        let serviceData = data["service_data"] as? [String: Any] ?? [:]
        guard let message = (serviceData["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty,
              !Self.commandMessages.contains(message), !message.hasPrefix("command_") else { return }
        let settings = NotchSettings.shared
        if !settings.knownNotifyServices.contains(service) {
            settings.knownNotifyServices.append(service)
            settings.knownNotifyServices.sort()
        }
        guard settings.notificationsEnabled, settings.isServiceMirrored(service) else { return }
        enqueue(NotchNotification(title: serviceData["title"] as? String ?? "", message: message, service: service))
    }

    func sendTestNotification() {
        enqueue(NotchNotification(title: L("Test"),
                                  message: L("Aceasta este o notificare de test din HassNotch. Dacă textul nu încape, se derulează de la stânga la dreapta."),
                                  service: "test"))
    }

    /// The same notification sent to several devices (phone + watch) is shown only once.
    private func enqueue(_ notification: NotchNotification) {
        let key = notification.title + "|" + notification.message
        if let last = lastNotificationKey, last.key == key, Date().timeIntervalSince(last.at) < 10 { return }
        lastNotificationKey = (key, Date())
        recentNotifications.insert(notification, at: 0)
        if recentNotifications.count > 15 { recentNotifications.removeLast(recentNotifications.count - 15) }
        notificationQueue.append(notification)
        showNextNotification()
    }

    private func showNextNotification() {
        guard currentNotification == nil, !notificationQueue.isEmpty else { return }
        let next = notificationQueue.removeFirst()
        let settings = NotchSettings.shared
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            currentNotification = next
            notificationAttention = settings.notificationAttention
        }
        settings.playNotificationSound()
        if settings.notificationAttention {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3.5))
                guard let self, self.currentNotification?.id == next.id else { return }
                withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) { self.notificationAttention = false }
            }
        }
        // Stays for at least the chosen duration, but long enough for long text to scroll through once.
        let scrollTime = 1.5 + (Double(next.text.count) * 7 + 48) / 45
        let duration = max(NotchSettings.shared.notificationDuration, min(scrollTime, 60))
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                self.currentNotification = nil
                self.notificationAttention = false
            }
            try? await Task.sleep(for: .milliseconds(700))
            self.showNextNotification()
        }
    }

    // MARK: - Values on the collapsed island

    /// Toggles "always show"; when enabled, the entity gets the first free slot.
    func setAlwaysShow(_ on: Bool, for id: UUID) {
        var list = displayed
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        if on {
            // The slot is decided by the symmetric layout (1 → middle, 2 → left/right, 3 → all);
            // we only keep the order of the existing ones.
            let style = NotchSettings.shared.style
            for (place, slot) in CollapsedPosition.layout(list, style: style) {
                if let j = list.firstIndex(where: { $0.id == slot.id }) { list[j].collapsedPosition = place }
            }
            list[index].alwaysShow = true
            list[index].collapsedPosition = nil
        } else {
            list[index].alwaysShow = false
            list[index].collapsedPosition = nil
        }
        displayed = list
    }

    /// Moves a value to another slot; if the slot is taken, the two values swap places.
    func setCollapsedPosition(_ position: CollapsedPosition, for id: UUID) {
        var list = displayed
        let layout = CollapsedPosition.layout(list, style: NotchSettings.shared.style)
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        let previous = layout.first { $0.value.id == id }?.key
        // Pin the current slots, so nothing "jumps" after the change.
        for (place, slot) in layout {
            if let j = list.firstIndex(where: { $0.id == slot.id }) { list[j].collapsedPosition = place }
        }
        if let occupant = layout[position], occupant.id != id,
           let j = list.firstIndex(where: { $0.id == occupant.id }) {
            list[j].collapsedPosition = previous
        }
        list[index].collapsedPosition = position
        displayed = list
    }

    // MARK: - Charging state

    /// The last direction each displayed entity's value moved in (+1 up, -1 down).
    private var trends: [String: (direction: Int, at: Date)] = [:]

    private func recordTrends(from old: [HAEntity]) {
        let tracked = displayed.filter { $0.chargeEnabled == true && ($0.chargeSource ?? .automatic) == .automatic }
        guard !tracked.isEmpty else { return }
        for slot in tracked {
            guard let previous = old.first(where: { $0.entity_id == slot.entityID })?.numericValue,
                  let current = entities.first(where: { $0.entity_id == slot.entityID })?.numericValue,
                  previous != current else { continue }
            trends[slot.entityID] = (current > previous ? 1 : -1, Date())
        }
    }

    /// The charging state of a displayed entity; nil if the option is off or it's unknown.
    func chargeState(for slot: DisplayedEntity) -> ChargeState? {
        guard slot.chargeEnabled == true else { return nil }
        switch slot.chargeSource ?? .automatic {
        case .automatic:
            // The last value change, if it happened in the last 15 minutes.
            guard let trend = trends[slot.entityID], Date().timeIntervalSince(trend.at) < 15 * 60 else {
                return .idle
            }
            return trend.direction > 0 ? .charging : .discharging
        case .stateSensor:
            guard let sensor = entity(slot.chargeEntityID ?? "") else { return nil }
            return Self.chargeState(fromText: sensor.state, isBinary: sensor.entity_id.hasPrefix("binary_sensor."))
        case .powerSensor:
            guard let sensor = entity(slot.chargeEntityID ?? ""), var power = sensor.numericValue else { return nil }
            if slot.chargeInvert == true { power = -power }
            // Below ~20 W we treat the battery as idle (measurement noise).
            let threshold = sensor.attributes.unit_of_measurement?.lowercased() == "kw" ? 0.02 : 20
            if abs(power) < threshold { return .idle }
            return power > 0 ? .charging : .discharging
        }
    }

    /// Recognizes the usual states: on/off, charging, discharging, idle, not charging…
    static func chargeState(fromText text: String, isBinary: Bool) -> ChargeState {
        let state = text.lowercased()
        if isBinary { return state == "on" ? .charging : .idle }
        if state.contains("discharg") || state.contains("descarc") { return .discharging }
        // Idle states that still contain "charg": NOT_READY, CHARGE_COMPLETE, CHARGE_TARGET_REACHED,
        // PAUSED, FAULT (FordPass and other EV integrations).
        let idleWords = ["not", "no_", "no ", "complete", "reached", "full", "pause", "fault",
                         "error", "wait", "schedul", "stopped", "finished"]
        if idleWords.contains(where: state.contains) { return .idle }
        if state.contains("charg") || state.contains("încarc") || state.contains("incarc") { return .charging }
        return .idle
    }

    /// Starts (or restarts) the real-time subscription to the displayed entities.
    func startLive() {
        liveTask?.cancel()
        liveTask = nil
        liveConnected = false
        liveSubscribedIDs = liveEntityIDs
        // The connection is needed even with no entities shown, for notifications.
        guard isConfigured, !liveSubscribedIDs.isEmpty || NotchSettings.shared.notificationsEnabled else { return }
        if wakeObserver == nil {
            // After sleep the connection is usually dead: reconnect right after wake.
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.startLive() }
            }
        }
        liveTask = Task { [weak self] in await self?.runLiveLoop() }
    }

    /// Reconnects forever, with growing pauses (1, 2, 4 … max 30 s).
    private func runLiveLoop() async {
        var delay: Double = 1
        while !Task.isCancelled {
            let started = Date()
            await runLiveSession()
            liveConnected = false
            if Task.isCancelled { return }
            if Date().timeIntervalSince(started) > 60 { delay = 1 } // it worked fine for a while
            try? await Task.sleep(for: .seconds(delay))
            delay = min(delay * 2, 30)
        }
    }

    private func runLiveSession() async {
        guard let base = Self.normalizedURL(serverURL), let token = loadToken(),
              var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return }
        parts.scheme = parts.scheme == "https" ? "wss" : "ws"
        parts.path = "/api/websocket"
        guard let url = parts.url else { return }
        let ids = Array(liveSubscribedIDs)
        let task = liveSession.webSocketTask(with: url)
        task.maximumMessageSize = 16 * 1024 * 1024
        task.resume()
        defer { task.cancel(with: .goingAway, reason: nil) }

        // Periodic ping; if the server is silent for more than 60 s, close and reconnect.
        liveLastMessage = Date()
        let heartbeat = Task { [weak self] in
            var pingID = 1_000
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                guard let self, !Task.isCancelled else { return }
                if Date().timeIntervalSince(self.liveLastMessage) > 60 {
                    task.cancel(with: .goingAway, reason: nil)
                    return
                }
                pingID += 1
                try? await self.sendJSON(task, ["id": pingID, "type": "ping"])
            }
        }
        defer { heartbeat.cancel() }

        do {
            _ = try await receiveJSON(task) // auth_required
            try await sendJSON(task, ["type": "auth", "access_token": token])
            guard try await receiveJSON(task)["type"] as? String == "auth_ok" else {
                readingsStatus = L("Home Assistant a refuzat tokenul pentru conexiunea în timp real.")
                return
            }
            // Subscribe ONLY to the displayed entities; HA sends their state, then only the changes.
            if !ids.isEmpty {
                try await sendJSON(task, ["id": 1, "type": "subscribe_entities", "entity_ids": ids])
            }
            // Notifications: every notify.* call (like those sent to a phone) goes over the event
            // bus as "call_service". HA only allows this subscription for admin users.
            if NotchSettings.shared.notificationsEnabled {
                try await sendJSON(task, ["id": 2, "type": "subscribe_events", "event_type": "call_service"])
            }
            while !Task.isCancelled {
                let message = try await receiveJSON(task)
                liveLastMessage = Date()
                let type = message["type"] as? String
                let id = message["id"] as? Int
                if type == "result", message["success"] as? Bool != true {
                    if id == 1 { return } // subscription refused → periodic polling remains
                    if id == 2 {
                        notificationsStatus = L("Home Assistant nu permite citirea notificărilor cu acest token (e nevoie de un utilizator administrator).")
                    }
                    continue
                }
                if type == "result", id == 2 {
                    notificationsStatus = L("Ascult notificările din Home Assistant.")
                }
                guard type == "event", let event = message["event"] as? [String: Any] else { continue }
                if id == 1 { applyLiveEvent(event) }
                if id == 2, let data = event["data"] as? [String: Any] { handleServiceCall(data) }
            }
        } catch {
            // Connection dropped: the loop above reconnects.
        }
    }

    /// The compact subscribe_entities format: "a" = full state, "c" = changes, "r" = removed.
    private func applyLiveEvent(_ event: [String: Any]) {
        if let added = event["a"] as? [String: [String: Any]] {
            for (id, compressed) in added {
                liveRaw[id] = ["state": compressed["s"] ?? "",
                               "attributes": compressed["a"] ?? [String: Any]()]
                pendingLive.insert(id)
            }
        }
        if let changed = event["c"] as? [String: [String: Any]] {
            for (id, diff) in changed {
                var raw = liveRaw[id] ?? ["state": "", "attributes": [String: Any]()]
                var attributes = raw["attributes"] as? [String: Any] ?? [:]
                if let plus = diff["+"] as? [String: Any] {
                    if let state = plus["s"] { raw["state"] = state }
                    if let changedAttributes = plus["a"] as? [String: Any] {
                        attributes.merge(changedAttributes) { $1 }
                    }
                }
                if let minus = diff["-"] as? [String: Any], let removed = minus["a"] as? [String] {
                    removed.forEach { attributes.removeValue(forKey: $0) }
                }
                raw["attributes"] = attributes
                liveRaw[id] = raw
                pendingLive.insert(id)
            }
        }
        if let removed = event["r"] as? [String] {
            for id in removed {
                liveRaw[id] = nil
                pendingLive.insert(id)
            }
        }
        liveConnected = true
        scheduleLiveFlush()
    }

    /// Sensors that change very often don't redraw the island dozens of times per second:
    /// changes are batched and applied at most ~2.5 times per second.
    private func scheduleLiveFlush() {
        guard !flushScheduled else { return }
        flushScheduled = true
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            self?.flushLive()
        }
    }

    private func flushLive() {
        flushScheduled = false
        guard !pendingLive.isEmpty else { return }
        var updated = entities
        for id in pendingLive {
            let index = updated.firstIndex { $0.entity_id == id }
            if let raw = liveRaw[id], let entity = HAEntity(id: id, raw: raw) {
                if let index { updated[index] = entity } else { updated.append(entity) }
            } else if let index {
                updated.remove(at: index)
            }
        }
        pendingLive.removeAll()
        entities = updated
        readingsAvailable = true
        readingsUpdated = Date()
        readingsStatus = L("În timp real · %@ entități urmărite", liveSubscribedIDs.count)
    }

    /// Reads the configuration of all dashboards over the WebSocket and keeps min/max
    /// from Gauge cards (Home Assistant doesn't expose these values through the REST API).
    func refreshDashboardRanges() async {
        guard !loadingRanges, isConfigured, let base = Self.normalizedURL(serverURL),
              let token = loadToken(),
              var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return }
        parts.scheme = parts.scheme == "https" ? "wss" : "ws"
        parts.path = "/api/websocket"
        guard let url = parts.url else { return }
        loadingRanges = true
        defer { loadingRanges = false }
        let task = session.webSocketTask(with: url)
        task.resume()
        defer { task.cancel(with: .goingAway, reason: nil) }
        // 20 s limit: if the server doesn't answer, close the connection (receive throws).
        let watchdog = Task {
            try? await Task.sleep(for: .seconds(20))
            if !Task.isCancelled { task.cancel(with: .goingAway, reason: nil) }
        }
        defer { watchdog.cancel() }
        do {
            _ = try await receiveJSON(task) // auth_required
            try await sendJSON(task, ["type": "auth", "access_token": token])
            guard try await receiveJSON(task)["type"] as? String == "auth_ok" else {
                rangesStatus = L("Home Assistant a refuzat tokenul pentru citirea dashboard-urilor.")
                return
            }
            var nextID = 1
            var paths: [String?] = [nil] // nil = the default dashboard
            if let list = try await wsRequest(task, id: nextID, ["type": "lovelace/dashboards/list"]) as? [[String: Any]] {
                paths += list.compactMap { $0["url_path"] as? String }
            }
            nextID += 1
            var found: [String: GaugeRange] = [:]
            for path in paths {
                var payload: [String: Any] = ["type": "lovelace/config"]
                if let path { payload["url_path"] = path }
                if let config = try await wsRequest(task, id: nextID, payload) {
                    Self.collectGauges(in: config, into: &found)
                }
                nextID += 1
            }
            guard base == Self.normalizedURL(serverURL) else { return }
            dashboardRanges = found
            rangesStatus = found.isEmpty
                ? L("Nu am găsit carduri Gauge cu min/max în dashboard-uri.")
                : L("Intervale preluate din %@ carduri Gauge (%@ dashboard-uri).", found.count, paths.count)
        } catch {
            rangesStatus = L("Nu am putut citi dashboard-urile. Folosesc ultimele intervale salvate.")
        }
    }

    private func sendJSON(_ task: URLSessionWebSocketTask, _ object: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        try await task.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func receiveJSON(_ task: URLSessionWebSocketTask) async throws -> [String: Any] {
        let data: Data
        switch try await task.receive() {
        case .string(let text): data = Data(text.utf8)
        case .data(let raw): data = raw
        @unknown default: data = Data()
        }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Sends a command and waits for the reply with the same id. Returns `result`, or nil on error.
    private func wsRequest(_ task: URLSessionWebSocketTask, id: Int, _ payload: [String: Any]) async throws -> Any? {
        var message = payload
        message["id"] = id
        try await sendJSON(task, message)
        while true {
            let reply = try await receiveJSON(task)
            guard reply["id"] as? Int == id else { continue }
            return reply["success"] as? Bool == true ? reply["result"] : nil
        }
    }

    /// Recursively finds `type: gauge` cards (also inside stacks, sections, etc.).
    /// As in Home Assistant, a card without min/max means 0–100.
    private static func collectGauges(in node: Any, into found: inout [String: GaugeRange]) {
        if let dict = node as? [String: Any] {
            if dict["type"] as? String == "gauge", let entity = dict["entity"] as? String {
                let min = number(dict["min"]) ?? 0
                let max = number(dict["max"]) ?? 100
                if max > min, found[entity] == nil {
                    found[entity] = GaugeRange(min: min, max: max)
                }
            }
            for value in dict.values { collectGauges(in: value, into: &found) }
        } else if let array = node as? [Any] {
            for value in array { collectGauges(in: value, into: &found) }
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }

    /// Reads the saved list; on first launch it migrates the two batteries from the old version.
    private static func loadDisplayed() -> [DisplayedEntity] {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "displayedEntities"),
           let saved = try? JSONDecoder().decode([DisplayedEntity].self, from: data) {
            return Array(saved.prefix(NotchLayout.maxItems))
        }
        var migrated: [DisplayedEntity] = []
        if let home = defaults.string(forKey: "homeBatteryID"), !home.isEmpty {
            migrated.append(DisplayedEntity(entityID: home, label: "CASĂ", icon: "house.fill"))
        }
        if let car = defaults.string(forKey: "carBatteryID"), !car.isEmpty {
            migrated.append(DisplayedEntity(entityID: car, label: "PUMA", icon: "car.fill"))
        }
        return migrated
    }
    func refreshEntities() async {
        guard !refreshing, isConfigured, let base = Self.normalizedURL(serverURL),
              let token = loadToken() else { return }
        refreshing = true
        defer { refreshing = false }
        var request = URLRequest(url: base.appendingPathComponent("api/states"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await session.data(for: request)
            guard base == Self.normalizedURL(serverURL) else { return }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw ConnectionError.message(L("Nu pot citi senzorii. Verifică conexiunea și tokenul."))
            }
            entities = try JSONDecoder().decode([HAEntity].self, from: data)
            readingsAvailable = true
            readingsUpdated = Date()
            readingsStatus = L("%@ entități citite din Home Assistant", entities.count)
        } catch {
            guard base == Self.normalizedURL(serverURL) else { return }
            readingsAvailable = false
            readingsStatus = L("Date indisponibile · reîncerc automat")
        }
    }
    private let keychainService = "HassNotch.HomeAssistant"
    private let keychainAccount = "accessToken"
    private let redirectDelegate = NoRedirectDelegate()
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config, delegate: redirectDelegate, delegateQueue: nil)
    }()

    private init() {
        serverURL = UserDefaults.standard.string(forKey: "haServerURL") ?? ""
        hasSavedToken = loadToken() != nil
    }
    var isConfigured: Bool { !serverURL.isEmpty && hasSavedToken }

    static func normalizedURL(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Address without a scheme (e.g. 100.101.102.103:8123 or ha.tail1234.ts.net:8123) → http://
        if !text.isEmpty, !text.contains("://") { text = "http://" + text }
        guard var parts = URLComponents(string: text),
              let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/" else { return nil }
        parts.scheme = scheme
        parts.host = host.lowercased()
        parts.path = ""
        return parts.url
    }

    /// The token, read once from the Keychain and kept in memory while the app runs.
    private var cachedToken: String?

    private func tokenQuery(dataProtection: Bool) -> [String: Any] {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: keychainService,
                                    kSecAttrAccount as String: keychainAccount]
        if dataProtection { query[kSecUseDataProtectionKeychain as String] = true }
        return query
    }

    /// The modern (iOS-style) Keychain ties access to the signing team, not to each build,
    /// so it doesn't ask for the system password. Only works if the app is signed with a Team.
    private lazy var dataProtectionAvailable: Bool = {
        var query = tokenQuery(dataProtection: true)
        query[kSecReturnAttributes as String] = true
        return SecItemCopyMatching(query as CFDictionary, nil) != errSecMissingEntitlement
    }()

    private func saveToken(_ token: String) -> Bool {
        // Try the modern Keychain first; if the signature doesn't allow it (e.g. a copy
        // moved to another Mac), fall back to the classic Keychain, which works for any app.
        let saved = writeToken(token, dataProtection: true) || writeToken(token, dataProtection: false)
        if saved { cachedToken = token }
        return saved
    }

    private func writeToken(_ token: String, dataProtection: Bool) -> Bool {
        let data = Data(token.utf8)
        let base = tokenQuery(dataProtection: dataProtection)
        let result = SecItemUpdate(base as CFDictionary,
                                  [kSecValueData as String: data] as CFDictionary)
        if result == errSecSuccess { return true }
        if result != errSecItemNotFound {
            // An old item created by a different signature of the app: replace it.
            SecItemDelete(base as CFDictionary)
        }
        var item = base
        item[kSecValueData as String] = data
        if dataProtection {
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    private func readToken(dataProtection: Bool) -> String? {
        var query = tokenQuery(dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func loadToken() -> String? {
        if let cachedToken { return cachedToken }
        if let token = readToken(dataProtection: true) {
            cachedToken = token
            return token
        }
        // A token saved by older versions in the classic Keychain: read it once
        // and, if possible, move it to the modern Keychain.
        guard let token = readToken(dataProtection: false) else { return nil }
        if dataProtectionAvailable { _ = writeToken(token, dataProtection: true) }
        cachedToken = token
        return token
    }

    @discardableResult
    func connect(address: String? = nil, token newToken: String = "") async -> Bool {
        guard !isConnecting else { return false }
        guard let base = Self.normalizedURL(address ?? serverURL) else {
            status = L("Introdu adresa de bază, de exemplu http://homeassistant.local:8123, fără calea dashboardului.")
            return false
        }
        let typed = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        // A saved token belongs only to the saved server.
        let saved = Self.normalizedURL(serverURL) == base ? loadToken() : nil
        guard let token = typed.isEmpty ? saved : typed, !token.isEmpty else {
            status = L("Introdu un token de acces pentru acest server.")
            return false
        }
        isConnecting = true
        status = L("Verific conexiunea…")
        defer { isConnecting = false }
        var request = URLRequest(url: base.appendingPathComponent("api/config"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw ConnectionError.invalidResponse }
            switch response.statusCode {
            case 200: break
            case 401, 403: throw ConnectionError.message(L("Token invalid sau acces refuzat. Verifică tokenul în profilul Home Assistant."))
            case 300..<400: throw ConnectionError.message(L("Serverul redirecționează cererea. Introdu adresa finală Home Assistant."))
            default: throw ConnectionError.message(L("Serverul a răspuns cu eroarea HTTP %@.", response.statusCode))
            }
            let info = try JSONDecoder().decode(ServerInfo.self, from: data)
            guard !info.version.isEmpty else { throw ConnectionError.invalidResponse }
            guard saveToken(token) else {
                throw ConnectionError.message(L("Conexiunea funcționează, dar tokenul nu a putut fi salvat în Keychain. Încearcă din nou."))
            }
            if Self.normalizedURL(serverURL) != base {
                entities = []
                readingsAvailable = false
                displayed = []
                dashboardRanges = [:]
            }
            serverURL = base.absoluteString
            UserDefaults.standard.set(serverURL, forKey: "haServerURL")
            hasSavedToken = true
            homeName = info.location_name
            version = info.version
            connected = true
            lastChecked = Date()
            status = L("Conexiune verificată. Configurarea a fost salvată.")
            await refreshEntities()
            // Real time starts right away; dashboard ranges are read in parallel.
            startLive()
            Task { await refreshDashboardRanges() }
            return true
        } catch {
            if Self.normalizedURL(serverURL) == base { connected = false }
            if let error = error as? ConnectionError {
                status = error.localizedDescription
            } else if error is DecodingError {
                status = L("Adresa nu a returnat configurația Home Assistant. Verifică serverul.")
            } else {
                status = L("Nu pot contacta Home Assistant. Verifică adresa, rețeaua și dacă serverul este pornit.")
                    + "\n(" + error.localizedDescription + ")"
            }
            return false
        }
    }
    private struct ServerInfo: Decodable {
        let location_name: String
        let version: String
    }
    private enum ConnectionError: LocalizedError {
        case invalidResponse
        case message(String)
        var errorDescription: String? {
            switch self {
            case .invalidResponse: return L("Răspuns Home Assistant invalid.")
            case .message(let text): return text
            }
        }
    }
}

struct HAEntity: Decodable, Identifiable {
    let entity_id: String
    let state: String
    let last_updated: String
    let attributes: Attributes
    var id: String { entity_id }
    var name: String { attributes.friendly_name ?? entity_id }
    var percentage: Double? {
        guard attributes.unit_of_measurement == "%", let value = Double(state),
              value.isFinite, (0...100).contains(value) else { return nil }
        return value
    }
    var percentageText: String {
        percentage.map { "\(Int($0.rounded()))%" } ?? "—"
    }
    private var isUnavailable: Bool { state == "unavailable" || state == "unknown" }
    /// The value shown in the gauge, without the unit.
    var valueText: String {
        if isUnavailable { return "—" }
        if let value = Double(state), value.isFinite {
            return value.formatted(.number.precision(.fractionLength(0...1)))
        }
        if entity_id.hasPrefix("binary_sensor.") {
            return state == "on" ? L("Da") : L("Nu")
        }
        return state
    }
    /// The unit shown next to the value (numeric values only).
    var displayUnit: String? {
        guard !isUnavailable, Double(state) != nil,
              let unit = attributes.unit_of_measurement, !unit.isEmpty else { return nil }
        return unit
    }
    /// Short text for the lists in Settings.
    var summaryText: String {
        displayUnit.map { "\(valueText) \($0)" } ?? valueText
    }
    /// The state's numeric value, if any.
    var numericValue: Double? {
        guard let value = Double(state), value.isFinite else { return nil }
        return value
    }
    struct Attributes: Decodable {
        let friendly_name: String?
        let unit_of_measurement: String?
        let device_class: String?
        /// min/max exist on number and input_number entities.
        let min: Double?
        let max: Double?

        private enum CodingKeys: String, CodingKey {
            case friendly_name, unit_of_measurement, device_class, min, max
        }

        // Lenient: an attribute of an unexpected type doesn't break decoding of all entities.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            friendly_name = (try? c.decodeIfPresent(String.self, forKey: .friendly_name)) ?? nil
            unit_of_measurement = (try? c.decodeIfPresent(String.self, forKey: .unit_of_measurement)) ?? nil
            device_class = (try? c.decodeIfPresent(String.self, forKey: .device_class)) ?? nil
            min = (try? c.decodeIfPresent(Double.self, forKey: .min)) ?? nil
            max = (try? c.decodeIfPresent(Double.self, forKey: .max)) ?? nil
        }
    }
}

extension HAEntity {
    /// Builds an entity from the state received over the WebSocket.
    init?(id: String, raw: [String: Any]) {
        let object: [String: Any] = ["entity_id": id,
                                     "state": raw["state"] as? String ?? "",
                                     "last_updated": "",
                                     "attributes": raw["attributes"] ?? [String: Any]()]
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let entity = try? JSONDecoder().decode(HAEntity.self, from: data) else { return nil }
        self = entity
    }
}
