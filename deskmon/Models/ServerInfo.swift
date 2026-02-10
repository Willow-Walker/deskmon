import Foundation

struct NetworkSample: Sendable {
    let download: Double
    let upload: Double
    /// Wall-clock time when this sample was received.
    let time: TimeInterval // Date.timeIntervalSinceReferenceDate
}

enum ConnectionPhase: Sendable {
    case connecting   // No data yet
    case syncing      // Got snapshot, establishing live stream
    case live         // SSE delivering events (or timed into live)
}

@MainActor
@Observable
final class ServerInfo: Identifiable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var token: String
    var status: ServerStatus = .offline
    var stats: ServerStats? = nil
    var containers: [DockerContainer] = []
    var processes: [ProcessInfo] = []
    var services: [ServiceInfo] = []
    var networkHistory: [NetworkSample] = []
    var connectionPhase: ConnectionPhase = .connecting
    var hasConnectedOnce = false

    /// Timestamp of the last services SSE event; drives the refresh countdown.
    var lastServicesUpdate: Date?

    /// Keep enough samples to cover the visible window plus a small buffer
    /// for the Catmull-Rom spline context at edges.
    static let maxNetworkSamples = 65
    /// Duration of the visible time window in seconds.
    static let windowDuration: TimeInterval = 60

    init(id: UUID = UUID(), name: String, host: String, port: Int = 7654, token: String = "") {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.token = token
    }

    func appendNetworkSample(_ network: NetworkStats) {
        let sample = NetworkSample(
            download: network.downloadBytesPerSec,
            upload: network.uploadBytesPerSec,
            time: Date.timeIntervalSinceReferenceDate
        )
        networkHistory.append(sample)
        if networkHistory.count > Self.maxNetworkSamples {
            networkHistory.removeFirst(networkHistory.count - Self.maxNetworkSamples)
        }
    }
}
