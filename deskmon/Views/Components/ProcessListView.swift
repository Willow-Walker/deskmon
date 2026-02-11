import SwiftUI

struct ProcessListView: View {
    let processes: [ProcessInfo]
    var selectedPID: Int32? = nil
    var onSelect: ((ProcessInfo) -> Void)?

    @State private var hoveredPID: Int32?

    /// Tracks processes we've seen recently, keyed by PID.
    /// Prevents rows from flickering in/out when a process hovers
    /// at the boundary of the agent's top-N list.
    @State private var knownProcesses: [Int32: (process: ProcessInfo, lastSeen: Date)] = [:]

    private static let gracePeriod: TimeInterval = 10

    private var stableProcesses: [ProcessInfo] {
        let now = Date()
        let currentByPID = Dictionary(uniqueKeysWithValues: processes.map { ($0.pid, $0) })

        return knownProcesses.compactMap { pid, entry -> ProcessInfo? in
            // Use fresh data if still present
            if let current = currentByPID[pid] { return current }
            // Keep recently-disappeared processes with stale values
            if now.timeIntervalSince(entry.lastSeen) < Self.gracePeriod { return entry.process }
            return nil
        }
        .sorted {
            if abs($0.memoryMB - $1.memoryMB) < 1 { return $0.pid < $1.pid }
            return $0.memoryMB > $1.memoryMB
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeaderView(title: "Top Processes", count: processes.count)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Column headers
                HStack(spacing: 6) {
                    Text("")
                        .frame(width: 16)
                    Text("")
                    Spacer(minLength: 8)
                    Text("CPU")
                        .frame(width: 44, alignment: .trailing)
                    Text("MEM")
                        .frame(width: 52, alignment: .trailing)
                    if onSelect != nil {
                        Text("")
                            .frame(width: 12)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                Divider().background(Theme.cardBorder)

                ForEach(Array(stableProcesses.enumerated()), id: \.element.pid) { index, process in
                    let isSelected = selectedPID == process.pid
                    let isHovered = hoveredPID == process.pid

                    processRow(process, rank: index + 1, isSelected: isSelected, isHovered: isHovered)
                        .contentShape(.rect)
                        .onTapGesture { onSelect?(process) }
                        .onHover { hoveredPID = $0 ? process.pid : nil }
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    if index < stableProcesses.count - 1 {
                        Divider()
                            .background(Theme.cardBorder)
                            .padding(.leading, 36)
                    }
                }
            }
            .animation(.smooth(duration: 0.3), value: stableProcesses.map(\.pid))
            .cardStyle(cornerRadius: 10)
        }
        .onAppear { mergeProcesses() }
        .onChange(of: processes.map(\.pid).sorted()) { _, _ in mergeProcesses() }
    }

    private func mergeProcesses() {
        let now = Date()
        for p in processes {
            knownProcesses[p.pid] = (p, now)
        }
        knownProcesses = knownProcesses.filter {
            now.timeIntervalSince($0.value.lastSeen) < Self.gracePeriod
        }
    }

    // MARK: - Row

    private func processRow(_ process: ProcessInfo, rank: Int, isSelected: Bool, isHovered: Bool) -> some View {
        HStack(spacing: 6) {
            Text("\(rank)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.quaternary)
                .frame(width: 16, alignment: .trailing)

            Text(process.name)
                .font(.caption)
                .foregroundStyle(process.cpuPercent > 10 ? cpuColor(process.cpuPercent) : .primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.caption.monospacedDigit())
                .foregroundStyle(cpuColor(process.cpuPercent))
                .frame(width: 44, alignment: .trailing)
                .contentTransition(.numericText())

            Text(String(format: "%.0f MB", process.memoryMB))
                .font(.caption.monospacedDigit())
                .foregroundStyle(memoryColor(process.memoryMB))
                .frame(width: 52, alignment: .trailing)
                .contentTransition(.numericText())

            // Chevron — hover only
            if onSelect != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                    .opacity(isHovered || isSelected ? 1 : 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            isSelected ? Theme.accent.opacity(0.1) :
            (isHovered ? Color.white.opacity(0.04) : .clear),
            in: .rect(cornerRadius: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Theme.accent.opacity(0.25) : .clear, lineWidth: 1)
        )
    }

    // MARK: - Resource Colors

    private func cpuColor(_ value: Double) -> Color {
        if value > 50 { return Theme.critical }
        if value > 20 { return Theme.warning }
        if value > 5 { return Theme.cpu }
        return .secondary
    }

    private func memoryColor(_ mb: Double) -> Color {
        if mb > 500 { return Theme.warning }
        if mb > 200 { return Theme.memory }
        return .secondary
    }
}
