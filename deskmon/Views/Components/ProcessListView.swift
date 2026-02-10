import SwiftUI

struct ProcessListView: View {
    let processes: [ProcessInfo]
    var onKill: ((ProcessInfo) -> Void)?

    @State private var killingPID: Int32?
    @State private var confirmKill: ProcessInfo?

    private var sortedProcesses: [ProcessInfo] {
        processes.sorted { $0.cpuPercent > $1.cpuPercent }
    }

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
                if onKill != nil {
                    Spacer().frame(width: 28)
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)

            VStack(spacing: 0) {
                ForEach(Array(sortedProcesses.enumerated()), id: \.element.pid) { index, process in
                    processRow(process, rank: index + 1)

                    if index < sortedProcesses.count - 1 {
                        Divider()
                            .padding(.leading, 30)
                    }
                }
            }
            .cardStyle(cornerRadius: 8)
        }
        .padding(10)
        .cardStyle()
        .alert(
            "Kill Process",
            isPresented: Binding(
                get: { confirmKill != nil },
                set: { if !$0 { confirmKill = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { confirmKill = nil }
            Button("Kill", role: .destructive) {
                if let process = confirmKill {
                    onKill?(process)
                }
                confirmKill = nil
            }
        } message: {
            if let process = confirmKill {
                Text("Send SIGTERM to \"\(process.name)\" (PID \(process.pid))?")
            }
        }
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

            if onKill != nil {
                if killingPID == process.pid {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 20, height: 20)
                } else {
                    Button {
                        confirmKill = process
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}
