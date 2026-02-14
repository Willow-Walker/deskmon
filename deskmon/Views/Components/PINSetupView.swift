import SwiftUI

/// Post-onboarding PIN setup prompt. Also used in settings to change PIN.
struct PINSetupView: View {
    @Environment(AppLockManager.self) private var lockManager
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var step: SetupStep = .enter
    @State private var errorMessage: String?

    enum SetupStep {
        case enter
        case confirm
    }

    /// Whether this is the initial onboarding prompt (shows skip) or a settings change.
    var isOnboarding: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: step == .enter ? "lock.open" : "lock")
                .font(.system(size: 28))
                .foregroundStyle(Theme.accent)

            Text(step == .enter ? "Set a PIN" : "Confirm PIN")
                .font(.headline)

            Text(step == .enter
                 ? "Set a 4-digit PIN to lock deskmon"
                 : "Enter the same PIN again")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // PIN circles
            let currentPin = step == .enter ? pin : confirmPin
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < currentPin.count ? Theme.accent : Color.clear)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .strokeBorder(index < currentPin.count ? Theme.accent : Color.secondary.opacity(0.5), lineWidth: 1.5)
                        )
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.critical)
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
                        errorMessage = nil
                        switch step {
                        case .enter:
                            if !pin.isEmpty { pin.removeLast() }
                        case .confirm:
                            if !confirmPin.isEmpty { confirmPin.removeLast() }
                        }
                    } label: {
                        Image(systemName: "delete.left")
                            .font(.body)
                            .frame(width: 52, height: 44)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 16) {
                if isOnboarding {
                    Button("Skip") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }

                if step == .confirm {
                    Button("Back") {
                        step = .enter
                        confirmPin = ""
                        errorMessage = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }

    private func keypadButton(_ digit: String) -> some View {
        Button {
            errorMessage = nil
            switch step {
            case .enter:
                guard pin.count < 4 else { return }
                pin.append(digit)
                if pin.count == 4 {
                    step = .confirm
                }
            case .confirm:
                guard confirmPin.count < 4 else { return }
                confirmPin.append(digit)
                if confirmPin.count == 4 {
                    finalize()
                }
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

    private func finalize() {
        guard pin == confirmPin else {
            errorMessage = "PINs don't match"
            confirmPin = ""
            return
        }

        do {
            try lockManager.setPIN(pin)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
