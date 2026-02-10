import SwiftUI

struct ProcessListView: View {
    let processes: [ProcessInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeaderView(title: "Top Processes", count: processes.count)
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                Text("PID")
                    .frame(width: 48, alignment: .leading)
                Spacer()
                Text("CPU")
                    .frame(width: 48, alignment: .trailing)
                Text("MEM")
                    .frame(width: 56, alignment: .trailing)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)

            VStack(spacing: 0) {
                ForEach(Array(processes.enumerated()), id: \.element.pid) { index, process in
                    processRow(process, rank: index + 1)

                    if index < processes.count - 1 {
                        Divider()
                            .padding(.leading, 30)
                    }
                }
            }
            .cardStyle(cornerRadius: 8)
        }
        .padding(10)
        .cardStyle()
    }

    private func processRow(_ process: ProcessInfo, rank: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(rank)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.quaternary)
                .frame(width: 14, alignment: .trailing)

            Text(process.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Spacer()

            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(process.cpuPercent > 50 ? Theme.critical : .secondary)
                .frame(width: 48, alignment: .trailing)
                .contentTransition(.numericText())

            Text(String(format: "%.0f MB", process.memoryMB))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}
