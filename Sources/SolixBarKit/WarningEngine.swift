import Foundation

/// Bewertet Snapshots und meldet Warn-Ereignisse genau einmal pro Vorfall.
///
/// Reine Zustandsmaschine ohne AppKit/UserNotifications — vollständig per
/// Unit-Test treibbar. Der Zustand lebt nur für die Laufzeit der App; nach
/// einem Neustart beginnt die Bewertung frisch (bewusst: kein veralteter
/// persistierter Zustand).
struct WarningEngine {
    struct Config: Equatable {
        var batteryLowEnabled = false
        /// Prozent-Schwelle; gefeuert wird beim Abwärts-Durchgang.
        var batteryLowThreshold = 20
        var pvStallEnabled = false
        /// So lange muss die PV durchgehend (nahe) 0 liefern, bevor gewarnt wird.
        var pvStallMinutes = 15
        /// "Hat kürzlich erzeugt": Maximum der letzten Stunde muss darüber liegen.
        var pvStallMinRecentWatts = 50
        var pvWindowEnabled = false
        /// Tagesfenster (lokale Stunden), in dem 0 W immer verdächtig ist.
        var pvWindowStartHour = 9
        var pvWindowEndHour = 17
        var perPVEnabled = false
    }

    enum Event: Equatable {
        case batteryLow(percent: Int)
        case pvStalled
        case pvChannelDead(index: Int)
    }

    /// Unterhalb dieser Leistung gilt ein Eingang als "liefert nichts";
    /// fängt Messrauschen um 0 W ab.
    static let deadbandWatts = 5
    /// Rückblick für "hat kürzlich erzeugt".
    private static let lookback: TimeInterval = 60 * 60
    /// Hysterese: Akku-Warnung erst wieder scharf ab Schwelle + 5.
    private static let batteryRearmMargin = 5

    private var solarHistory: [(date: Date, watts: Int)] = []
    private var batteryArmed = true
    private var pvStallArmed = true
    private var pvStalledSince: Date?
    private var channelDeadSince: [Int: Date] = [:]
    private var channelArmed: [Int: Bool] = [:]

    /// Meldet alle NEU eingetretenen Warn-Ereignisse für diesen Snapshot.
    /// `calendar` ist nur fürs Zeitfenster relevant (Tests reichen UTC durch).
    mutating func evaluate(
        snapshot: SolixSnapshot,
        at date: Date,
        config: Config,
        calendar: Calendar = .current
    ) -> [Event] {
        var events: [Event] = []
        if let event = evaluateBattery(snapshot: snapshot, config: config) {
            events.append(event)
        }
        if let event = evaluateSolar(snapshot: snapshot, at: date, config: config, calendar: calendar) {
            events.append(event)
        }
        events.append(contentsOf: evaluateChannels(snapshot: snapshot, at: date, config: config))
        return events
    }

    /// Aktuell aktive Warnbedingungen (für die Menü-Anzeige, solange die
    /// Bedingung anhält) — unabhängig davon, ob das Ereignis schon gemeldet wurde.
    private(set) var activeEvents: [Event] = []

    private mutating func evaluateBattery(snapshot: SolixSnapshot, config: Config) -> Event? {
        activeEvents.removeAll { if case .batteryLow = $0 { true } else { false } }
        guard config.batteryLowEnabled, let percent = snapshot.batteryPercent else { return nil }
        if percent > config.batteryLowThreshold + Self.batteryRearmMargin {
            batteryArmed = true
            return nil
        }
        guard percent <= config.batteryLowThreshold else { return nil }
        activeEvents.append(.batteryLow(percent: percent))
        guard batteryArmed else { return nil }
        batteryArmed = false
        return .batteryLow(percent: percent)
    }

    private mutating func evaluateSolar(
        snapshot: SolixSnapshot,
        at date: Date,
        config: Config,
        calendar: Calendar
    ) -> Event? {
        activeEvents.removeAll { $0 == .pvStalled }
        guard let solar = snapshot.solarWatts else { return nil }
        solarHistory.append((date, solar))
        solarHistory.removeAll { $0.date < date.addingTimeInterval(-Self.lookback) }

        guard config.pvStallEnabled || config.pvWindowEnabled else { return nil }

        if solar >= Self.deadbandWatts {
            pvStalledSince = nil
            if solar >= config.pvStallMinRecentWatts {
                pvStallArmed = true
            }
            return nil
        }

        if pvStalledSince == nil { pvStalledSince = date }
        let stalledMinutes = date.timeIntervalSince(pvStalledSince ?? date) / 60
        guard stalledMinutes >= Double(config.pvStallMinutes) else { return nil }

        // Einbruch: vorher wurde nennenswert erzeugt (nachts also nie).
        let recentMax = solarHistory.map(\.watts).max() ?? 0
        let collapsed = config.pvStallEnabled && recentMax >= config.pvStallMinRecentWatts
        // Zeitfenster: tagsüber ist 0 W auch ohne vorherige Erzeugung verdächtig.
        let hour = calendar.component(.hour, from: date)
        let inWindow = config.pvWindowEnabled
            && hour >= config.pvWindowStartHour && hour < config.pvWindowEndHour
        guard collapsed || inWindow else { return nil }

        activeEvents.append(.pvStalled)
        guard pvStallArmed else { return nil }
        pvStallArmed = false
        return .pvStalled
    }

    private mutating func evaluateChannels(
        snapshot: SolixSnapshot,
        at date: Date,
        config: Config
    ) -> [Event] {
        activeEvents.removeAll { if case .pvChannelDead = $0 { true } else { false } }
        guard config.perPVEnabled, let channels = snapshot.pvWatts, channels.count > 1 else {
            channelDeadSince.removeAll()
            return []
        }
        var events: [Event] = []
        for (index, watts) in channels.enumerated() {
            let siblingsMax = channels.enumerated()
                .filter { $0.offset != index }
                .map(\.element)
                .max() ?? 0
            // Geschwister-Kanäle liefern = es ist hell; dieser Kanal sollte auch.
            guard watts < Self.deadbandWatts, siblingsMax >= config.pvStallMinRecentWatts else {
                channelDeadSince[index] = nil
                if watts >= Self.deadbandWatts { channelArmed[index] = true }
                continue
            }
            if channelDeadSince[index] == nil { channelDeadSince[index] = date }
            let deadMinutes = date.timeIntervalSince(channelDeadSince[index] ?? date) / 60
            guard deadMinutes >= Double(config.pvStallMinutes) else { continue }
            activeEvents.append(.pvChannelDead(index: index))
            if channelArmed[index, default: true] {
                channelArmed[index] = false
                events.append(.pvChannelDead(index: index))
            }
        }
        return events
    }
}
