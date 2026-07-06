import Foundation

protocol SolixDataProvider: Sendable {
    func fetchSnapshot() async throws -> SolixSnapshot
}

enum SolixProviderError: LocalizedError, Sendable {
    case missingCommand
    case missingURL
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingCommand:
            "Kein JSON-Befehl konfiguriert."
        case .missingURL:
            "Keine JSON-URL konfiguriert."
        case .commandFailed(let message):
            message
        }
    }
}

final class DemoSolixDataProvider: SolixDataProvider {
    func fetchSnapshot() async throws -> SolixSnapshot {
        var snapshot = SolixSnapshot.demo
        let minute = Calendar.current.component(.minute, from: Date())
        snapshot.solarWatts = 400 + ((minute * 37) % 420)
        snapshot.homeWatts = 220 + ((minute * 19) % 260)
        snapshot.batteryPercent = 65 + (minute % 25)
        snapshot.batteryWatts = (snapshot.solarWatts ?? 0) - (snapshot.homeWatts ?? 0)
        snapshot.updatedAt = Date()
        return snapshot
    }
}

final class CommandSolixDataProvider: SolixDataProvider {
    private let command: String

    init(command: String) {
        self.command = command
    }

    func fetchSnapshot() async throws -> SolixSnapshot {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SolixProviderError.missingCommand
        }

        let command = command
        return try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]

            let output = Pipe()
            let error = Pipe()
            process.standardOutput = output
            process.standardError = error

            try process.run()
            process.waitUntilExit()

            let data = output.fileHandleForReading.readDataToEndOfFile()
            let errorData = error.fileHandleForReading.readDataToEndOfFile()

            guard process.terminationStatus == 0 else {
                let message = String(data: errorData, encoding: .utf8) ?? "Befehl fehlgeschlagen."
                throw SolixProviderError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            return try SnapshotDecoder.decode(data)
        }.value
    }
}

final class URLSolixDataProvider: SolixDataProvider {
    private let urlString: String

    init(urlString: String) {
        self.urlString = urlString
    }

    func fetchSnapshot() async throws -> SolixSnapshot {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            throw SolixProviderError.missingURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try SnapshotDecoder.decode(data)
    }
}

enum SnapshotDecoder {
    static func decode(_ data: Data) throws -> SolixSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SolixSnapshot.self, from: data)
    }
}
