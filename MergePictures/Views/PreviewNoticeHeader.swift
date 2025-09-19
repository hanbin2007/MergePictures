import SwiftUI

struct PreviewNoticeHeader: View {
    var isPresented: Bool
    var closeAction: () -> Void
    var neverShowAction: () -> Void

    var body: some View {
        Group {
            if isPresented {
                NoticeBanner(
                    closeAction: closeAction,
                    neverShowAction: neverShowAction
                )
                .padding(.horizontal)
                .padding(.top, 45)
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color.clear)
    }
}

#if DEBUG
#Preview {
    PreviewNoticeHeader(
        isPresented: true,
        closeAction: {},
        neverShowAction: {}
    )
}
#endif
