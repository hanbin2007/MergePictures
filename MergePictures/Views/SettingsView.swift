import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("Settings"))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #else
        VStack(alignment: .leading) {
            Text(LocalizedStringKey("Settings")).font(.title2).bold()
            content
                .padding(.top)
            HStack { Spacer(); Button("Done") { dismiss() } }
        }
        .padding()
        #endif
    }

    private var content: some View {
        Form {
            Section {
                Picker("Preview Quality", selection: $viewModel.previewQuality) {
                    ForEach(PreviewQuality.allCases) { q in
                        switch q {
                        case .low: Text(LocalizedStringKey("Low")).tag(q)
                        case .medium: Text(LocalizedStringKey("Medium")).tag(q)
                        case .high: Text(LocalizedStringKey("High")).tag(q)
                        }
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(LocalizedStringKey("Preview Quality"))
            } footer: {
                Text(LocalizedStringKey("Preview Quality Detail"))
            }

            Section {
                HStack {
                    Spacer()
                    resetButton
                    Spacer()
                }
                .listRowInsets(EdgeInsets())
            } header: {
                Text(LocalizedStringKey("Reset Hidden Notices"))
            } footer: {
                Text(LocalizedStringKey("Reset Hidden Notices Detail"))
            }
        }
    }

    @ViewBuilder
    private var resetButton: some View {
        Button(action: { viewModel.resetPreviewNoticeSuppression() }) {
            Label(LocalizedStringKey("Reset Now"), systemImage: "arrow.counterclockwise")
                .bold()
        }
        .buttonStyle(.bordered)
    }
}

#if DEBUG
#Preview {
    SettingsView(viewModel: .preview)
}
#endif
