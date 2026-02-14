import Foundation
import os

// MARK: - Agent API Response

/// Matches the actual JSON shape from deskmon-agent GET /stats
struct AgentStatsResponse: Codable, Sendable {
    let system: ServerStats
    let containers: [DockerContainer]
    let processes: [ProcessInfo]?
}

// MARK: - Container Actions

enum ContainerAction: String, Sendable {
    case start, stop, restart
}

struct ControlResponse: Codable, Sendable {
    let message: String?
    let error: String?
}

// MARK: - Errors

enum AgentError: LocalizedError, Sendable, Equatable {
    case invalidURL
    case httpError(Int)
    case unreachable

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid server URL"
        case .httpError(let code): "HTTP \(code)"
        case .unreachable: "Agent unreachable"
        }
    }
}

// MARK: - SSE Events

/// Decoded event from the SSE stream.
enum ServerEvent: Sendable {
    case system(ServerStats, [ProcessInfo])
    case docker([DockerContainer])
    case keepalive
}

/// Matches the "system" SSE event payload from the agent.
private struct SystemEventPayload: Codable, Sendable {
    let system: ServerStats
    let processes: [ProcessInfo]
}

// MARK: - Client

/// HTTP/SSE client for the deskmon agent.
///
/// All requests go through a tunnel base URL (e.g. `http://127.0.0.1:54321`)
/// provided by SSHManager. No auth headers needed — SSH handles authentication.
final class AgentClient: Sendable {
    static let shared = AgentClient()

    private static let log = Logger(subsystem: "prowlsh.deskmon", category: "AgentClient")

    /// Dedicated session for SSE streams — caching disabled, long timeouts.
    private let sseSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300     // 5 min idle (server keepalive every 30s)
        config.timeoutIntervalForResource = 0      // No total transfer limit
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    /// Fetch full stats (system + containers) from the agent through the tunnel.
    func fetchStats(baseURL: String) async throws -> AgentStatsResponse {
        guard let url = URL(string: "\(baseURL)/stats") else {
            Self.log.error("Invalid URL: \(baseURL)/stats")
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        Self.log.info("GET \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                Self.log.error("No HTTP response from \(url.absoluteString)")
                throw AgentError.httpError(0)
            }

            Self.log.info("\(url.absoluteString) -> \(http.statusCode)")

            guard http.statusCode == 200 else {
                throw AgentError.httpError(http.statusCode)
            }

            return try JSONDecoder().decode(AgentStatsResponse.self, from: data)
        } catch let error as AgentError {
            throw error
        } catch let error as DecodingError {
            Self.log.error("Decode error for \(url.absoluteString): \(error)")
            throw error
        } catch {
            let nsError = error as NSError
            Self.log.error("Network error for \(url.absoluteString): domain=\(nsError.domain) code=\(nsError.code) \(nsError.localizedDescription)")
            throw AgentError.unreachable
        }
    }

    /// Perform a container action (start/stop/restart).
    func performContainerAction(baseURL: String, containerID: String, action: ContainerAction) async throws -> String {
        guard let url = URL(string: "\(baseURL)/containers/\(containerID)/\(action.rawValue)") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 35

        Self.log.info("POST \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AgentError.httpError(0)
        }

        guard http.statusCode == 200 else {
            throw AgentError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(ControlResponse.self, from: data)

        if decoded.error != nil {
            throw AgentError.httpError(http.statusCode)
        }

        return decoded.message ?? action.rawValue
    }

    /// Kill a process by PID.
    func killProcess(baseURL: String, pid: Int32) async throws -> String {
        guard let url = URL(string: "\(baseURL)/processes/\(pid)/kill") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 35

        Self.log.info("POST \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AgentError.httpError(0)
        }

        guard http.statusCode == 200 else {
            throw AgentError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(ControlResponse.self, from: data)

        if decoded.error != nil {
            throw AgentError.httpError(http.statusCode)
        }

        return decoded.message ?? "killed"
    }

    /// Restart the agent process.
    func restartAgent(baseURL: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/agent/restart") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10

        Self.log.info("POST \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AgentError.httpError(0)
        }

        guard http.statusCode == 200 else {
            throw AgentError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(ControlResponse.self, from: data)
        return decoded.message ?? "restarting"
    }

    // MARK: - SSE Streaming

    /// Opens a persistent SSE connection to GET /stats/stream and yields decoded events.
    func streamStats(baseURL: String) -> AsyncThrowingStream<ServerEvent, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                guard let url = URL(string: "\(baseURL)/stats/stream") else {
                    continuation.finish(throwing: AgentError.invalidURL)
                    return
                }

                var request = URLRequest(url: url)
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

                Self.log.info("SSE connecting to \(url.absoluteString)")

                do {
                    let (bytes, response) = try await self.sseSession.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AgentError.httpError(0))
                        return
                    }

                    guard http.statusCode == 200 else {
                        continuation.finish(throwing: AgentError.httpError(http.statusCode))
                        return
                    }

                    Self.log.info("SSE stream connected")

                    var currentEvent = ""
                    var dataBuffer = ""

                    // Iterate over raw bytes instead of `bytes.lines` to avoid
                    // URLSession's internal line-buffering which batches data
                    // and causes "burst update" behavior (10-30s stalls).
                    var lineBuffer = Data()
                    for try await byte in bytes {
                        if Task.isCancelled { break }

                        if byte == UInt8(ascii: "\n") {
                            let line = String(data: lineBuffer, encoding: .utf8) ?? ""
                            lineBuffer.removeAll(keepingCapacity: true)

                            if line.hasPrefix("event: ") {
                                currentEvent = String(line.dropFirst(7))
                            } else if line.hasPrefix("data: ") {
                                dataBuffer = String(line.dropFirst(6))
                            } else if line.hasPrefix(":") {
                                // Comment line (keepalive)
                                continuation.yield(.keepalive)
                            } else if line.isEmpty && !currentEvent.isEmpty {
                                // Empty line = end of event
                                if let event = Self.decodeSSEEvent(type: currentEvent, data: dataBuffer) {
                                    continuation.yield(event)
                                }
                                currentEvent = ""
                                dataBuffer = ""
                            }
                        } else if byte != UInt8(ascii: "\r") {
                            // Skip \r (SSE uses \n or \r\n line endings)
                            lineBuffer.append(byte)
                        }
                    }

                    continuation.finish()
                } catch {
                    Self.log.error("SSE stream error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func decodeSSEEvent(type: String, data: String) -> ServerEvent? {
        guard let jsonData = data.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()

        switch type {
        case "system":
            do {
                let payload = try decoder.decode(SystemEventPayload.self, from: jsonData)
                return .system(payload.system, payload.processes)
            } catch {
                log.error("SSE decode error (system): \(error)")
                return nil
            }
        case "docker":
            do {
                let containers = try decoder.decode([DockerContainer].self, from: jsonData)
                return .docker(containers)
            } catch {
                log.error("SSE decode error (docker): \(error)")
                return nil
            }
        default:
            return nil
        }
    }
}
