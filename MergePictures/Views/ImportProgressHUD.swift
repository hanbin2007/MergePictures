import SwiftUI

struct ImportProgressHUD: View {
    let progress: Double

    private var percentText: String {
        let pct = max(0, min(100, Int((progress * 100).rounded())))
        return "\(pct)%"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .imageScale(.large)
                Text(LocalizedStringKey("Importing…"))
                    .font(.headline)
                    .bold()
            }
            HStack(spacing: 10) {
                ProgressView(value: progress)
                    .tint(.accentColor)
                    .frame(width: 260)
                    .scaleEffect(x: 1, y: 1.6, anchor: .center)
                    .animation(.easeOut(duration: 0.2), value: progress)
                Text(percentText)
                    .font(.headline)
                    .monospacedDigit()
                    .frame(minWidth: 44, alignment: .trailing)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Importing… \(percentText)"))
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.94).combined(with: .opacity),
                removal: .scale(scale: 0.96).combined(with: .opacity)
            )
        )
    }
}

#if DEBUG
#Preview {
    ImportProgressHUD(progress: 0.42)
        .padding()
}
#endif
