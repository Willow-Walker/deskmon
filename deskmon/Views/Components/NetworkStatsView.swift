import SwiftUI

struct NetworkStatsView: View {
    let network: NetworkStats
    let history: [NetworkSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row: labels + current speeds
            HStack(spacing: 0) {
                Image(systemName: "network")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("  Network")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.download)
                        Text(ByteFormatter.formatSpeed(network.downloadBytesPerSec))
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .contentTransition(.numericText())
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.upload)
                        Text(ByteFormatter.formatSpeed(network.uploadBytesPerSec))
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .contentTransition(.numericText())
                    }
                }
            }

            // Sparkline graph
            NetworkSparkline(history: history)
                .frame(height: 48)
        }
        .padding(10)
        .cardStyle()
    }
}

// MARK: - Sparkline

private struct NetworkSparkline: View {
    let history: [NetworkSample]

    var body: some View {
        Canvas { context, size in
            let samples = history
            guard samples.count > 1 else {
                // Draw empty baseline
                let baseline = Path { p in
                    p.move(to: CGPoint(x: 0, y: size.height))
                    p.addLine(to: CGPoint(x: size.width, y: size.height))
                }
                context.stroke(baseline, with: .color(.secondary.opacity(0.15)), lineWidth: 0.5)
                return
            }

            // Find the peak value across both channels for scaling
            let peak = samples.reduce(0.0) { max($0, max($1.download, $1.upload)) }
            let ceiling = peak > 0 ? peak * 1.15 : 1 // 15% headroom

            let stepX = size.width / CGFloat(ServerInfo.maxNetworkSamples - 1)
            let offsetX = CGFloat(ServerInfo.maxNetworkSamples - samples.count) * stepX

            // Draw download (filled area)
            let dlPath = buildPath(
                samples: samples.map(\.download),
                size: size, ceiling: ceiling,
                stepX: stepX, offsetX: offsetX
            )
            let dlFill = buildFillPath(
                samples: samples.map(\.download),
                size: size, ceiling: ceiling,
                stepX: stepX, offsetX: offsetX
            )

            context.fill(dlFill, with: .linearGradient(
                Gradient(colors: [Theme.download.opacity(0.3), Theme.download.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))
            context.stroke(dlPath, with: .color(Theme.download.opacity(0.8)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            // Draw upload (filled area)
            let ulPath = buildPath(
                samples: samples.map(\.upload),
                size: size, ceiling: ceiling,
                stepX: stepX, offsetX: offsetX
            )
            let ulFill = buildFillPath(
                samples: samples.map(\.upload),
                size: size, ceiling: ceiling,
                stepX: stepX, offsetX: offsetX
            )

            context.fill(ulFill, with: .linearGradient(
                Gradient(colors: [Theme.upload.opacity(0.25), Theme.upload.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))
            context.stroke(ulPath, with: .color(Theme.upload.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .clipShape(.rect(cornerRadius: 6))
        .background(Color.white.opacity(0.03), in: .rect(cornerRadius: 6))
    }

    // MARK: - Path Builders

    private func buildPath(samples: [Double], size: CGSize, ceiling: Double, stepX: CGFloat, offsetX: CGFloat) -> Path {
        Path { path in
            for (i, value) in samples.enumerated() {
                let x = offsetX + CGFloat(i) * stepX
                let y = size.height - (CGFloat(value / ceiling) * size.height)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    // Smooth curve between points
                    let prevX = offsetX + CGFloat(i - 1) * stepX
                    let prevValue = samples[i - 1]
                    let prevY = size.height - (CGFloat(prevValue / ceiling) * size.height)
                    let midX = (prevX + x) / 2
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: midX, y: prevY),
                        control2: CGPoint(x: midX, y: y)
                    )
                }
            }
        }
    }

    private func buildFillPath(samples: [Double], size: CGSize, ceiling: Double, stepX: CGFloat, offsetX: CGFloat) -> Path {
        var path = buildPath(samples: samples, size: size, ceiling: ceiling, stepX: stepX, offsetX: offsetX)
        // Close the path along the bottom
        let lastX = offsetX + CGFloat(samples.count - 1) * stepX
        let firstX = offsetX
        path.addLine(to: CGPoint(x: lastX, y: size.height))
        path.addLine(to: CGPoint(x: firstX, y: size.height))
        path.closeSubpath()
        return path
    }
}
