import SwiftUI
import AppKit

struct ImageSidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var hoveredId: UUID?

    var body: some View {
        List {
            Section(header: SidebarHeader(ascending: viewModel.sortAscending, toggleAction: viewModel.toggleSortOrder)) {
                ForEach(viewModel.images) { item in
                    SidebarRow(item: item,
                               hoveredId: $hoveredId,
                               deleteAction: { delete(item) })
                }
                .onMove(perform: move)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 300)
    }

    private func move(from source: IndexSet, to destination: Int) {
        viewModel.images.move(fromOffsets: source, toOffset: destination)
        viewModel.updatePreview()
    }

    private func delete(_ item: ImageItem) {
        if let idx = viewModel.images.firstIndex(where: { $0.id == item.id }) {
            viewModel.images.remove(at: idx)
            viewModel.updatePreview()
        }
    }
}

private struct SidebarHeader: View {
    var ascending: Bool
    var toggleAction: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("Images")
            Button(action: toggleAction) {
                Image(systemName: ascending ? "arrow.up" : "arrow.down")
            }
            .buttonStyle(.borderless)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SidebarRow: View {
    let item: ImageItem
    @Binding var hoveredId: UUID?
    var deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: item.image)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .cornerRadius(4)
            Text(item.url.lastPathComponent)
                .lineLimit(1)
            Spacer()
            Button(action: deleteAction) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .opacity(hoveredId == item.id ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .listRowInsets(EdgeInsets())
        .onHover { hovering in
            hoveredId = hovering ? item.id : nil
        }
    }
}

#if DEBUG
#Preview {
    ImageSidebarView(viewModel: .preview)
}
#endif
