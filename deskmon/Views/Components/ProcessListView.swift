import SwiftUI

struct ProcessListView: View {
    let processes: [ProcessInfo]
    var selectedPID: Int32? = nil
    var onSelect: ((ProcessInfo) -> Void)?

    @State private var hoveredPID: Int32?

    /// Remembers the last stable ordering so rows don't jump on every tick.
    @State private var displayOrder: [Int32] = []

    private static let maxVisible = 10

    /// Processes to display — capped at 10, with a stable sort to prevent jitter.
    private var stableProcesses: [ProcessInfo] {
        // Build lookup from the incoming data (already top-N from the agent).
        let byPID = Dictionary(uniqueKeysWithValues: processes.map { ($0.pid, $0) })

        // Start with the previous ordering, keeping only PIDs still present.
        var ordered = displayOrder.compactMap { byPID[$0] }

        // Append any new PIDs that weren't in the previous order.
        let existingPIDs = Set(ordered.map(\.pid))
        let newProcesses = processes
            .filter { !existingPIDs.contains($0.pid) }
            .sorted { score($0) > score($1) }
        ordered.append(contentsOf: newProcesses)

        // Re-sort only when positions are significantly wrong.
        // A process needs to outrank its neighbor by >5% combined score
        // to justify a swap, preventing jitter from tiny fluctuations.
        ordered = dampedSort(ordered)

        return Array(ordered.prefix(Self.maxVisible))
    }

    /// Combined resource score for ranking.
    private func score(_ p: ProcessInfo) -> Double {
        p.cpuPercent + p.memoryMB * 0.1
    }

    /// Sort that only swaps adjacent items when the score difference exceeds a threshold.
    private func dampedSort(_ items: [ProcessInfo]) -> [ProcessInfo] {
        guard items.count > 1 else { return items }
        var arr = items
        // Bubble pass — only swap when the lower-ranked item clearly dominates.
        var swapped = true
        while swapped {
            swapped = false
            for i in 0..<(arr.count - 1) {
                let scoreCurrent = score(arr[i])
                let scoreNext = score(arr[i + 1])
                // Only swap if the next item's score is meaningfully higher.
                if scoreNext > scoreCurrent + 5 {
                    arr.swapAt(i, i + 1)
                    swapped = true
                }
            }
        }
        return arr
    }

    var body: some View {
        let visible = stableProcesses

        VStack(alignment: .leading, spacing: 6) {
            SectionHeaderView(title: "Top Processes", count: visible.count)
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

                ForEach(Array(visible.enumerated()), id: \.element.pid) { index, process in
                    let isSelected = selectedPID == process.pid
                    let isHovered = hoveredPID == process.pid

                    processRow(process, rank: index + 1, isSelected: isSelected, isHovered: isHovered)
                        .contentShape(.rect)
                        .onTapGesture { onSelect?(process) }
                        .onHover { hoveredPID = $0 ? process.pid : nil }
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    if index < visible.count - 1 {
                        Divider()
                            .background(Theme.cardBorder)
                            .padding(.leading, 36)
                    }
                }
            }
            .animation(.smooth(duration: 0.3), value: visible.map(\.pid))
            .cardStyle(cornerRadius: 10)
        }
        .onChange(of: processes.map(\.pid).sorted()) { _, _ in
            displayOrder = stableProcesses.map(\.pid)
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
