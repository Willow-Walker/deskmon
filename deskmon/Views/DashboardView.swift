import SwiftUI

struct DashboardView: View {
    @Environment(ServerManager.self) private var serverManager
    @State private var selectedContainer: DockerContainer?
    @State private var selectedProcess: ProcessInfo?
    @State private var activeTab: DashboardTab = .overview
    @State private var selectedService: ServiceInfo?

    enum DashboardTab: String, CaseIterable {
        case overview = "Overview"
        case services = "Services"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let container = liveSelectedContainer {
                containerDetailPanel(container: container)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else if let process = liveSelectedProcess {
                processDetailPanel(process: process)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else if let service = selectedService,
                      let live = serverManager.selectedServer?.services.first(where: { $0.id == service.id }) ?? Optional(service) {
                serviceDetailPanel(service: live)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else {
                dashboardContent(manager: serverManager)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .clipped()
        .frame(width: 380, height: 580)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }

    // MARK: - Dashboard Content

    private func dashboardContent(manager: ServerManager) -> some View {
        @Bindable var mgr = manager

        return VStack(spacing: 0) {
            if serverManager.servers.count > 1 {
                Picker("Server", selection: $mgr.selectedServerID) {
                    ForEach(serverManager.servers) { server in
                        Text(server.name).tag(server.id as UUID?)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }

            if let server = serverManager.selectedServer {
                if server.connectionPhase == .live {
                    Picker("", selection: $activeTab) {
                        ForEach(DashboardTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                    switch activeTab {
                    case .overview:
                        ScrollView {
                            VStack(spacing: 10) {
                                ServerHeaderView(server: server)

                                if let stats = server.stats {
                                    SystemStatsView(stats: stats)
                                    NetworkStatsView(network: stats.network, history: server.networkHistory)
                                }

                                if !server.containers.isEmpty {
                                    ContainerListView(containers: server.containers) { container in
                                        withAnimation(.smooth(duration: 0.3)) {
                                            selectedProcess = nil
                                            selectedContainer = container
                                        }
                                    }
                                }

                                if !server.processes.isEmpty {
                                    ProcessListView(
                                        processes: server.processes,
                                        onSelect: { process in
                                            withAnimation(.smooth(duration: 0.3)) {
                                                selectedContainer = nil
                                                selectedProcess = process
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(12)
                        }
                        .animation(.smooth, value: serverManager.selectedServerID)

                    case .services:
                        ScrollView {
                            ServicesGridView(services: server.services, lastUpdate: server.lastServicesUpdate) { service in
                                withAnimation(.smooth(duration: 0.3)) {
                                    selectedService = service
                                }
                            }
                            .padding(12)
                        }
                    }
                } else if server.connectionPhase == .syncing {
                    GoingLiveView()
                } else {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Connecting...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }

                FooterView()
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else {
                Spacer()
                EmptyStateView()
                Spacer()
                FooterView()
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
    }

    // MARK: - Container Detail Panel

    private var liveSelectedContainer: DockerContainer? {
        guard let id = selectedContainer?.id,
              let server = serverManager.selectedServer else { return nil }
        return server.containers.first { $0.id == id }
    }

    private var liveSelectedProcess: ProcessInfo? {
        guard let selected = selectedProcess,
              let server = serverManager.selectedServer else { return nil }
        return server.processes.first { $0.pid == selected.pid } ?? selected
    }

    private func processDetailPanel(process: ProcessInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation(.smooth(duration: 0.3)) {
                        selectedProcess = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text(process.name)
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .hidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            ProcessDetailView(process: process)
        }
    }

    private func containerDetailPanel(container: DockerContainer) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation(.smooth(duration: 0.3)) {
                        selectedContainer = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text(container.name)
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .hidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            ContainerDetailView(container: container)
        }
    }

    // MARK: - Service Detail Panel

    private func serviceDetailPanel(service: ServiceInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation(.smooth(duration: 0.3)) {
                        selectedService = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Services")
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text(service.name)
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Services")
                }
                .hidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            ServiceDashboardView(service: service)
        }
    }
}
