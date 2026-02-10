import Foundation
import SwiftUI

struct DockerContainer: Identifiable, Sendable {
    var id: String
    var name: String
    var image: String
    var status: ContainerStatus
    var cpuPercent: Double
    var memoryUsageMB: Double
    var memoryLimitMB: Double
    var networkRxBytes: Int64
    var networkTxBytes: Int64
    var blockReadBytes: Int64
    var blockWriteBytes: Int64
    var pids: Int
    var startedAt: Date?

    // TODO: ports — [PortMapping] for exposed port mappings (e.g. 8080:80/tcp)
    // TODO: restartCount — number of times container has restarted
    // TODO: healthStatus — healthy/unhealthy/starting/none (requires container healthcheck)
    // TODO: healthLog — last health check output string

    var memoryPercent: Double {
        guard memoryLimitMB > 0 else { return 0 }
        return memoryUsageMB / memoryLimitMB * 100
    }

    var uptime: String? {
        guard let startedAt else { return nil }
        let seconds = Int(Date().timeIntervalSince(startedAt))
        return ByteFormatter.formatUptime(seconds)
    }

    enum ContainerStatus: String, Codable, Sendable {
        case running
        case stopped
        case restarting

        var label: String {
            rawValue.capitalized
        }

        var color: Color {
            switch self {
            case .running: Theme.healthy
            case .stopped: .secondary
            case .restarting: Theme.warning
            }
        }
    }
}

// MARK: - Codable

/// Custom Codable because the agent sends `startedAt` as an ISO 8601 string
/// (or empty string for stopped containers), but Swift expects `Date?`.
extension DockerContainer: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, image, status, cpuPercent, memoryUsageMB, memoryLimitMB
        case networkRxBytes, networkTxBytes, blockReadBytes, blockWriteBytes
        case pids, startedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        image = try c.decode(String.self, forKey: .image)
        status = try c.decode(ContainerStatus.self, forKey: .status)
        cpuPercent = try c.decode(Double.self, forKey: .cpuPercent)
        memoryUsageMB = try c.decode(Double.self, forKey: .memoryUsageMB)
        memoryLimitMB = try c.decode(Double.self, forKey: .memoryLimitMB)
        networkRxBytes = try c.decode(Int64.self, forKey: .networkRxBytes)
        networkTxBytes = try c.decode(Int64.self, forKey: .networkTxBytes)
        blockReadBytes = try c.decode(Int64.self, forKey: .blockReadBytes)
        blockWriteBytes = try c.decode(Int64.self, forKey: .blockWriteBytes)
        pids = try c.decode(Int.self, forKey: .pids)

        // Agent sends ISO 8601 string, empty string, or null
        if let dateString = try c.decodeIfPresent(String.self, forKey: .startedAt),
           !dateString.isEmpty {
            startedAt = ISO8601DateFormatter().date(from: dateString)
        } else {
            startedAt = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(image, forKey: .image)
        try c.encode(status, forKey: .status)
        try c.encode(cpuPercent, forKey: .cpuPercent)
        try c.encode(memoryUsageMB, forKey: .memoryUsageMB)
        try c.encode(memoryLimitMB, forKey: .memoryLimitMB)
        try c.encode(networkRxBytes, forKey: .networkRxBytes)
        try c.encode(networkTxBytes, forKey: .networkTxBytes)
        try c.encode(blockReadBytes, forKey: .blockReadBytes)
        try c.encode(blockWriteBytes, forKey: .blockWriteBytes)
        try c.encode(pids, forKey: .pids)
        if let startedAt {
            try c.encode(ISO8601DateFormatter().string(from: startedAt), forKey: .startedAt)
        } else {
            try c.encodeNil(forKey: .startedAt)
        }
    }
}
