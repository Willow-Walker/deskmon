import Combine
import SwiftUI

/// PIN entry overlay shown when a surface is locked.
struct AppLockView: View {
    @Environment(AppLockManager.self) private var lockManager
    let surface: LockSurface

    @State private var pin = ""
    @State private var shake = false
    @State private var showError = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(Theme.accent)

            Text("Enter PIN")
                .font(.headline)

            // PIN circles
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < pin.count ? Theme.accent : Color.clear)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .strokeBorder(index < pin.count ? Theme.accent : Color.secondary.opacity(0.5), lineWidth: 1.5)
                        )
                }
            }
            .offset(x: shake ? -8 : 0)

            if showError {
                if let end = lockManager.cooldownEnd {
                    CooldownLabel(end: end)
                } else {
                    Text("Wrong PIN")
                        .font(.caption)
                        .foregroundStyle(Theme.critical)
                }
            }

            // Keypad
            VStack(spacing: 10) {
                ForEach(0..<3) { row in
                    HStack(spacing: 14) {
                        ForEach(1...3, id: \.self) { col in
                            let digit = row * 3 + col
                            keypadButton(String(digit))
                        }
                    }
                }
                HStack(spacing: 14) {
                    Color.clear.frame(width: 52, height: 44)
                    keypadButton("0")
                    Button {
                        if !pin.isEmpty { pin.removeLast() }
                        showError = false
                    } label: {
                        Image(systemName: "delete.left")
                            .font(.body)
                            .frame(width: 52, height: 44)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .background(Theme.background.opacity(0.8))
    }

    private func keypadButton(_ digit: String) -> some View {
        Button {
            guard pin.count < 4 else { return }
            // Check cooldown
            if let end = lockManager.cooldownEnd, Date() < end {
                showError = true
                return
            }

            pin.append(digit)
            showError = false

            if pin.count == 4 {
                attemptUnlock()
            }
        } label: {
            Text(digit)
                .font(.title2.monospacedDigit())
                .frame(width: 52, height: 44)
                .background(Color.white.opacity(0.06), in: .rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Theme.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func attemptUnlock() {
        if lockManager.unlock(surface, pin: pin) {
            pin = ""
            showError = false
        } else {
            showError = true
            withAnimation(.default.speed(3).repeatCount(3, autoreverses: true)) {
                shake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                shake = false
                pin = ""
            }
        }
    }
}

/// Shows a live countdown during PIN cooldown.
private struct CooldownLabel: View {
    let end: Date

    @State private var remaining: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text("Try again in \(remaining)s")
            .font(.caption)
            .foregroundStyle(Theme.warning)
            .onAppear { remaining = max(0, Int(end.timeIntervalSinceNow)) }
            .onReceive(timer) { _ in remaining = max(0, Int(end.timeIntervalSinceNow)) }
    }
}
