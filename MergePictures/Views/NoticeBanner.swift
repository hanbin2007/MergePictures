 import SwiftUI

struct NoticeBanner: View {
    var closeAction: () -> Void
    var neverShowAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(red: 0.36, green: 0.27, blue: 0.00))
                .imageScale(.medium)
                .accessibilityHidden(true)

            Text(LocalizedStringKey("Preview Notice"))
                .font(.footnote)
                .foregroundColor(Color(red: 0.36, green: 0.27, blue: 0.00))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button(role: .none) {
                neverShowAction()
            } label: {
                Text(LocalizedStringKey("Don't Show Again"))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .cancel) {
                closeAction()
            } label: {
                Image(systemName: "xmark")
                    .imageScale(.small)
                    .font(.footnote)
                    .accessibilityLabel(LocalizedStringKey("Close"))
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 1.0, green: 0.9725, blue: 0.8823)) // #fff8e1
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.941, green: 0.851, blue: 0.549), lineWidth: 1) // #f0d98c
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(LocalizedStringKey("Preview Notice"))
    }
}

#if DEBUG
#Preview {
    NoticeBanner(closeAction: {}, neverShowAction: {})
        .padding()
}
#endif
