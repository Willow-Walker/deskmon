import SwiftUI

enum ServerStatus: String, Codable, CaseIterable {
    case healthy
    case warning
    case critical
    case unauthorized
    case offline

    var color: Color {
        switch self {
        case .healthy: Theme.healthy
        case .warning: Theme.warning
        case .critical: Theme.critical
        case .unauthorized: Theme.warning
        case .offline: .secondary
        }
    }

    var label: String {
        switch self {
        case .healthy: "Healthy"
        case .warning: "Warning"
        case .critical: "Critical"
        case .unauthorized: "Unauthorized"
        case .offline: "Offline"
        }
    }

    var systemImage: String {
        switch self {
        case .healthy: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        case .unauthorized: "lock.fill"
        case .offline: "wifi.slash"
        }
    }
}
