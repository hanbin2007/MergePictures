import SwiftUI

struct ImportProgressHUD: View {
    let progress: Double

    var body: some View {
        HStack(spacing: 10) {
            ProgressView(value: progress)
                .frame(width: 140)
            Text(LocalizedStringKey("Importing…"))
                .font(.footnote)
                .bold()
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(radius: 1)
    }
}

#if DEBUG
#Preview {
    ImportProgressHUD(progress: 0.42)
        .padding()
}
#endif

