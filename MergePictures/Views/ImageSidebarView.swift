import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ImageSidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    #if os(macOS)
    @State private var hoveredId: UUID?
    #endif

    var body: some View {
        List {
            Section(header: SidebarHeader(ascending: viewModel.sortAscending, toggleAction: viewModel.toggleSortOrder)) {
                ForEach(viewModel.images) { item in
                    #if os(macOS)
                    SidebarRow(item: item,
                               hoveredId: $hoveredId,
                               deleteAction: { delete(item) },
                               openAction: { viewModel.presentPreviewForOriginal(item) })
                    #else
                    SidebarRow(item: item,
                               deleteAction: { delete(item) },
                               openAction: { viewModel.presentPreviewForOriginal(item) })
                    #endif
                }
                .onMove(perform: move)
            }
        }
        .listStyle(.sidebar)
        #if os(macOS)
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 400)
        #endif
    }

    private func move(from source: IndexSet, to destination: Int) {
        viewModel.images.move(fromOffsets: source, toOffset: destination)
        viewModel.updatePreview()
    }

    private func delete(_ item: ImageItem) {
        viewModel.removeImage(item)
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

#if os(macOS)
private struct SidebarRow: View {
    let item: ImageItem
    @Binding var hoveredId: UUID?
    var deleteAction: () -> Void
    var openAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Clickable content area (thumbnail + name)
            HStack(spacing: 8) {
                Image(nsImage: item.preview)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .cornerRadius(4)
                Text(item.displayName)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: openAction)

            Spacer()

            // Delete button
            Button(action: deleteAction) {
                Image(systemName: "trash")
                    .foregroundColor(.primary)
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
#else
private struct SidebarRow: View {
    let item: ImageItem
    var deleteAction: () -> Void
    var openAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(uiImage: item.preview)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .cornerRadius(4)
            Text(item.displayName)
                .lineLimit(1)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: openAction)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .swipeActions { Button(role: .destructive, action: deleteAction) { Image(systemName: "trash") } }
    }
}
#endif

#if DEBUG
#Preview {
    ImageSidebarView(viewModel: .preview)
}
#endif
