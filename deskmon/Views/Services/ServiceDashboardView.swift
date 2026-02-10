import SwiftUI

struct ServiceDashboardView: View {
    let service: ServiceInfo

    var body: some View {
        switch service.pluginId {
        case "pihole":
            PiHoleDashboardView(service: service)
        default:
            GenericServiceDashboardView(service: service)
        }
    }
}
