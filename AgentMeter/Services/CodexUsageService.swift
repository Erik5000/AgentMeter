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
            process.waitUntilExit()
        }

        let writer = inputPipe.fileHandleForWriting
        do {
            try writeMessage(
                [
                    "method": "initialize",
                    "id": 0,
                    "params": [
                        "clientInfo": [
                            "name": AppIdentity.codexClientName,
                            "title": AppIdentity.displayName,
                            "version": appVersion
                        ]
                    ]
                ],
                to: writer
            )
        } catch {
            throw CodexUsageError.failedToStart
        }

        let responseData = try await readRateLimitsAfterInitialize(
            from: outputPipe.fileHandleForReading,
            writer: writer,
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

        guard let result = response.result else {
            throw CodexUsageError.invalidResponse
        }

        let multiBucketLimits = result.rateLimitsByLimitId?
            .compactMap { key, limits -> CodexUsageBucket? in
                limits.usageBucket(fallbackID: key, now: now)
            }
            .sorted { lhs, rhs in
                let lhsIsDefault = lhs.id.caseInsensitiveCompare("codex") == .orderedSame
                let rhsIsDefault = rhs.id.caseInsensitiveCompare("codex") == .orderedSame
                if lhsIsDefault != rhsIsDefault {
                    return lhsIsDefault
                }
                let lhsName = lhs.modeName ?? lhs.id
                let rhsName = rhs.modeName ?? rhs.id
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            } ?? []

        let buckets: [CodexUsageBucket]
        if multiBucketLimits.isEmpty {
            guard let legacyBucket = result.rateLimits?.usageBucket(fallbackID: "codex", now: now) else {
                throw CodexUsageError.invalidResponse
            }
            buckets = [legacyBucket]
        } else {
            buckets = multiBucketLimits
        }

        return CodexUsageData(
            buckets: buckets,
            planType: result.rateLimits?.planType ?? bucketsPlanType(result.rateLimitsByLimitId),
            lastUpdated: now
        )
    }

    private nonisolated static func bucketsPlanType(
        _ buckets: [String: RateLimitsRPCResponse.RateLimits]?
    ) -> String? {
        buckets?
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .compactMap { $0.value.planType }
            .first
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "unknown"
    }

    private nonisolated func writeMessage(_ message: [String: Any], to handle: FileHandle) throws {
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }

    private func readRateLimitsAfterInitialize(
        from handle: FileHandle,
        writer: FileHandle,
        process: Process
    ) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                var didCompleteHandshake = false
                for try await line in handle.bytes.lines {
                    guard let data = line.data(using: .utf8),
                          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let id = (object["id"] as? NSNumber)?.intValue else {
                        continue
                    }

                    if id == 0, !didCompleteHandshake {
                        if let error = object["error"] as? [String: Any] {
                            let message = error["message"] as? String ?? "Codex initialize failed."
                            throw CodexUsageError.serverError(message)
                        }
                        do {
                            try self.writeMessage(
                                ["method": "initialized", "params": [:]],
                                to: writer
                            )
                            try self.writeMessage(
                                ["method": "account/rateLimits/read", "id": 1],
                                to: writer
                            )
                        } catch {
                            throw CodexUsageError.failedToStart
                        }
                        didCompleteHandshake = true
                        continue
                    }

                    if id == 1 {
                        return data
                    }
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

    static func defaultExecutableCandidates(
        fileManager: FileManager,
        path: String? = ProcessInfo.processInfo.environment["PATH"]
    ) -> [URL] {
        let home = fileManager.homeDirectoryForCurrentUser
        var ordered: [URL] = []
        var seen = Set<String>()

        func append(_ url: URL) {
            if seen.insert(url.path).inserted {
                ordered.append(url)
            }
        }

        [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ].map(URL.init(fileURLWithPath:)).forEach(append)

        append(home.appendingPathComponent("Applications/ChatGPT.app/Contents/Resources/codex"))
        append(home.appendingPathComponent("Applications/Codex.app/Contents/Resources/codex"))
        append(home.appendingPathComponent(".local/bin/codex"))

        if let path {
            for component in path.split(separator: ":") where !component.isEmpty {
                append(
                    URL(fileURLWithPath: String(component), isDirectory: true)
                        .appendingPathComponent("codex")
                )
            }
        }

        return ordered
    }
}

private struct RateLimitsRPCResponse: Decodable {
    let result: ResultPayload?
    let error: ErrorPayload?

    struct ResultPayload: Decodable {
        let rateLimits: RateLimits?
        let rateLimitsByLimitId: [String: RateLimits]?
    }

    struct RateLimits: Decodable {
        let primary: Window?
        let secondary: Window?
        let planType: String?
        let limitId: String?
        let limitName: String?
        let normalModelSlug: String?

        func usageBucket(fallbackID: String, now: Date) -> CodexUsageBucket? {
            let windows = [primary, secondary].compactMap { $0 }
            guard !windows.isEmpty else { return nil }

            let sorted = windows.sorted { lhs, rhs in
                (lhs.windowDurationMins ?? .infinity) < (rhs.windowDurationMins ?? .infinity)
            }

            let session: Window?
            let longTerm: Window?
            if sorted.count > 1 {
                session = sorted.first
                longTerm = sorted.last
            } else if let only = sorted.first,
                      let duration = only.windowDurationMins,
                      duration >= 24 * 60 {
                session = nil
                longTerm = only
            } else {
                session = sorted.first
                longTerm = nil
            }

            return CodexUsageBucket(
                id: limitId ?? fallbackID,
                limitName: limitName,
                modelSlug: normalModelSlug,
                sessionUsage: session?.usageLimit(now: now),
                sessionWindowMinutes: session?.windowDurationMins,
                longTermUsage: longTerm?.usageLimit(now: now),
                longTermWindowMinutes: longTerm?.windowDurationMins
            )
        }
    }

    struct Window: Decodable {
        let usedPercent: Double
        let windowDurationMins: Double?
        let resetsAt: Double?

        func usageLimit(now: Date) -> UsageLimit {
            let fallbackMinutes = windowDurationMins ?? 300
            let resetAt = resetsAt.map { Date(timeIntervalSince1970: $0) }
                ?? now.addingTimeInterval(fallbackMinutes * 60)
            return UsageLimit(
                utilization: usedPercent,
                resetAt: resetAt
            )
        }
    }

    struct ErrorPayload: Decodable {
        let message: String
    }
}
