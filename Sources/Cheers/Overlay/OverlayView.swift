import CheersCore
import SwiftUI

struct OverlayView: View {
    let model: OverlayModel
    let meter: AudioMeter

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            if model.phase != .hidden {
                pill
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.55, anchor: .bottom).combined(with: .opacity),
                            removal: .scale(scale: 0.85, anchor: .bottom).combined(with: .opacity)
                        )
                    )
            }
        }
        .padding(.bottom, 10)
        .animation(.spring(response: 0.42, dampingFraction: 0.74), value: model.phase)
    }

    private var pill: some View {
        HStack(spacing: 10) {
            if model.phase == .listening(.handsFree) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .transition(.scale.combined(with: .opacity))
            }

            if showsWaveform {
                WaveformView(meter: meter, isListening: isListening)
                    .frame(width: 172, height: 38)
            }

            if model.phase == .listening(.handsFree) {
                stopButton
                    .transition(.scale.combined(with: .opacity))
            }

            if model.phase == .finished(.pasted) {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .transition(.blurReplace)
            }

            if let status {
                Label(status.text, systemImage: status.symbol)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .symbolRenderingMode(.hierarchical)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .transition(.blurReplace)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .glassEffect(.regular.tint(.black.opacity(0.55)), in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
        .environment(\.colorScheme, .dark)
    }

    private var stopButton: some View {
        Button {
            model.onStop?()
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color(red: 1, green: 0.32, blue: 0.4).gradient))
        }
        .buttonStyle(.plain)
    }

    private var isListening: Bool {
        if case .listening = model.phase { return true }
        return false
    }

    private var showsWaveform: Bool {
        isListening || model.phase == .transcribing
    }

    private var status: (text: String, symbol: String)? {
        switch model.phase {
        case .finished(.copied):
            ("Copied · ⌘V to paste", "doc.on.clipboard.fill")
        case .message(let text, let symbol):
            (text, symbol)
        default:
            nil
        }
    }
}
