import Foundation

struct SolixHistorySample: Codable, Sendable {
    var date: Date
    var batteryPercent: Int?
    var solarWatts: Int?
    var gridWatts: Int?
}

@MainActor
final class SolixHistoryStore {
    static let shared = SolixHistoryStore()

    private let defaults = UserDefaults.standard
    private let key = "solixHistorySamples"
    private let maxAge: TimeInterval = 31 * 24 * 60 * 60

    func record(_ snapshot: SolixSnapshot) {
        var values = allSamples()
        values.append(
            SolixHistorySample(
                date: snapshot.updatedAt,
                batteryPercent: snapshot.batteryPercent,
                solarWatts: snapshot.solarWatts,
                gridWatts: snapshot.gridWatts
            )
        )
        save(pruned(values, from: Date()))
    }

    func samples(duration: TimeInterval) -> [SolixHistorySample] {
        let cutoff = Date().addingTimeInterval(-duration)
        return allSamples().filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    func estimatedSolarKWh(since startDate: Date? = nil) -> Double {
        let samples = allSamples()
            .filter { sample in
                guard let startDate else { return true }
                return sample.date >= startDate
            }
            .sorted { $0.date < $1.date }
        guard samples.count >= 2 else { return 0 }

        return zip(samples, samples.dropFirst()).reduce(0) { total, pair in
            let first = pair.0
            let second = pair.1
            guard let firstWatts = first.solarWatts, let secondWatts = second.solarWatts else { return total }
            let seconds = second.date.timeIntervalSince(first.date)
            guard seconds > 0, seconds <= 30 * 60 else { return total }
            return total + (Double(firstWatts + secondWatts) / 2) * seconds / 3_600_000
        }
    }

    private func allSamples() -> [SolixHistorySample] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SolixHistorySample].self, from: data)) ?? []
    }

    private func save(_ samples: [SolixHistorySample]) {
        guard let data = try? JSONEncoder().encode(samples) else { return }
        defaults.set(data, forKey: key)
    }

    private func pruned(_ samples: [SolixHistorySample], from date: Date) -> [SolixHistorySample] {
        let cutoff = date.addingTimeInterval(-maxAge)
        let filtered = samples.filter { $0.date >= cutoff }
        guard filtered.count > 2000 else { return filtered }
        return Array(filtered.suffix(2000))
    }
}
