import Foundation

enum CodexUsageError: LocalizedError, Equatable {
    case notInstalled
    case failedToStart
    case timedOut
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Codex is not installed."
        case .failedToStart:
            return "Codex usage could not be started."
        case .timedOut:
            return "Codex usage did not respond in time."
        case .invalidResponse:
            return "Codex returned an invalid usage response."
        case .serverError(let message):
            return message
        }
    }
}

/// Reads the signed-in user's limits through Codex's local app-server protocol.
actor CodexUsageService: CodexUsageServiceProtocol {
    private let fileManager: FileManager
    private let executableCandidates: [URL]
    private let responseTimeout: Duration

    init(
        fileManager: FileManager = .default,
        executableCandidates: [URL]? = nil,
        responseTimeout: Duration = .seconds(10)
    ) {
        self.fileManager = fileManager
        self.executableCandidates = executableCandidates
            ?? Self.defaultExecutableCandidates(fileManager: fileManager)
        self.responseTimeout = responseTimeout
    }

    func fetchUsage() async throws -> CodexUsageData {
        guard let executableURL = executableCandidates.first(where: {
            fileManager.isExecutableFile(atPath: $0.path)
        }) else {
            throw CodexUsageError.notInstalled
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw CodexUsageError.failedToStart
        }

        defer {
            try? inputPipe.fileHandleForWriting.close()
            try? outputPipe.fileHandleForReading.close()
            if process.isRunning {
                process.terminate()
            }
        }

        do {
            try writeMessage(
                [
                    "method": "initialize",
                    "id": 0,
                    "params": [
                        "clientInfo": [
                            "name": "claudemeter",
                            "title": "ClaudeMeter",
                            "version": appVersion
                        ]
                    ]
                ],
                to: inputPipe.fileHandleForWriting
            )
            try writeMessage(
                ["method": "initialized", "params": [:]],
                to: inputPipe.fileHandleForWriting
            )
            try writeMessage(
                ["method": "account/rateLimits/read", "id": 1],
                to: inputPipe.fileHandleForWriting
            )
        } catch {
            throw CodexUsageError.failedToStart
        }

        let responseData = try await readResponse(
            withID: 1,
            from: outputPipe.fileHandleForReading,
            process: process
        )
        return try Self.parseRateLimitsResponse(responseData)
    }

    nonisolated static func parseRateLimitsResponse(
        _ data: Data,
        now: Date = Date()
    ) throws -> CodexUsageData {
        let response: RateLimitsRPCResponse
        do {
            response = try JSONDecoder().decode(RateLimitsRPCResponse.self, from: data)
        } catch {
            throw CodexUsageError.invalidResponse
        }

        if let message = response.error?.message {
            throw CodexUsageError.serverError(message)
        }

        guard let limits = response.result?.rateLimits,
              let primary = limits.primary else {
            throw CodexUsageError.invalidResponse
        }

        return CodexUsageData(
            sessionUsage: primary.usageLimit,
            sessionWindowMinutes: primary.windowDurationMins,
            weeklyUsage: limits.secondary?.usageLimit,
            weeklyWindowMinutes: limits.secondary?.windowDurationMins,
            planType: limits.planType,
            lastUpdated: now
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "unknown"
    }

    private func writeMessage(_ message: [String: Any], to handle: FileHandle) throws {
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }

    private func readResponse(
        withID expectedID: Int,
        from handle: FileHandle,
        process: Process
    ) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                for try await line in handle.bytes.lines {
                    guard let data = line.data(using: .utf8),
                          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          (object["id"] as? NSNumber)?.intValue == expectedID else {
                        continue
                    }
                    return data
                }
                throw CodexUsageError.invalidResponse
            }

            group.addTask { [responseTimeout] in
                try await Task.sleep(for: responseTimeout)
                if process.isRunning {
                    process.terminate()
                }
                throw CodexUsageError.timedOut
            }

            guard let response = try await group.next() else {
                throw CodexUsageError.invalidResponse
            }
            group.cancelAll()
            return response
        }
    }

    private static func defaultExecutableCandidates(fileManager: FileManager) -> [URL] {
        let home = fileManager.homeDirectoryForCurrentUser
        let fixedPaths = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ].map(URL.init(fileURLWithPath:))

        let userPaths = [
            home.appendingPathComponent("Applications/ChatGPT.app/Contents/Resources/codex"),
            home.appendingPathComponent("Applications/Codex.app/Contents/Resources/codex")
        ]

        return fixedPaths + userPaths
    }
}

private struct RateLimitsRPCResponse: Decodable {
    let result: ResultPayload?
    let error: ErrorPayload?

    struct ResultPayload: Decodable {
        let rateLimits: RateLimits?
    }

    struct RateLimits: Decodable {
        let primary: Window?
        let secondary: Window?
        let planType: String?
    }

    struct Window: Decodable {
        let usedPercent: Double
        let windowDurationMins: Double
        let resetsAt: Double

        var usageLimit: UsageLimit {
            UsageLimit(
                utilization: usedPercent,
                resetAt: Date(timeIntervalSince1970: resetsAt)
            )
        }
    }

    struct ErrorPayload: Decodable {
        let message: String
    }
}
