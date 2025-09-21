import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum CompactControlsDetent: Equatable {
    case collapsed
    case fraction(CGFloat)
    case medium
    case large
}

struct CompactControlsPanel<Content: View, BottomBar: View>: View {
    @Binding var isPresented: Bool
    @Binding var selected: CompactControlsDetent
    var bottomInset: CGFloat = 0
    let content: () -> Content
    let bottomBar: () -> BottomBar

    private let collapsedHeight: CGFloat = 100
    private let presentationAnimation = Animation.spring(response: 0.32, dampingFraction: 0.88)
    private let detentAnimation = Animation.interactiveSpring(response: 0.36, dampingFraction: 0.86, blendDuration: 0.2)
    private let dragResponsiveness: CGFloat = 0.65
    private let projectionBoost: CGFloat = 1.6
    private let directionalTrigger: CGFloat = 18
    private let detentOptions: [CompactControlsDetent] = [.collapsed, .fraction(0.35), .medium, .large]

    init(isPresented: Binding<Bool>,
         selected: Binding<CompactControlsDetent>,
         bottomInset: CGFloat = 0,
         @ViewBuilder content: @escaping () -> Content,
         @ViewBuilder bottomBar: @escaping () -> BottomBar) {
        self._isPresented = isPresented
        self._selected = selected
        self.bottomInset = bottomInset
        self.content = content
        self.bottomBar = bottomBar
    }

    var body: some View {
        GeometryReader { proxy in
            let safeBottom = proxy.safeAreaInsets.bottom
            let maxHeight = proxy.size.height + safeBottom

            ZStack(alignment: .bottom) {
                if isPresented {
                    panel(maxHeight: maxHeight, safeBottom: safeBottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            .animation(presentationAnimation, value: isPresented)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func panel(maxHeight: CGFloat, safeBottom: CGFloat) -> some View {
        let extraSpacing: CGFloat = bottomInset > 0 ? 8 : 0
        let additionalSafe: CGFloat = bottomInset > 0 ? safeBottom : 0
        let liftAmount = bottomInset + extraSpacing + additionalSafe
        let adjustedMaxHeight = max(maxHeight - liftAmount, height(for: .collapsed, maxHeight: maxHeight, safeBottom: safeBottom))
        let expandedHeight = height(for: selected, maxHeight: adjustedMaxHeight, safeBottom: safeBottom)
        let collapsedHeight = height(for: .collapsed, maxHeight: adjustedMaxHeight, safeBottom: safeBottom)
        let baseHeight = height(for: selected, maxHeight: adjustedMaxHeight, safeBottom: safeBottom)

        return PanelBody(
            height: expandedHeight,
            collapsed: collapsedHeight,
            maxHeight: adjustedMaxHeight,
            safeBottom: safeBottom,
            content: content,
            bottomBar: bottomBar,
            dragResponsiveness: dragResponsiveness,
            snapAnimation: detentAnimation
        ) { offset in
            let boostedOffset = offset * projectionBoost
            let magnitude = abs(boostedOffset)
            let direction = boostedOffset == 0 ? 0 : (boostedOffset > 0 ? 1 : -1)
            let projectedHeight = baseHeight - boostedOffset

            var target = selected

            if direction != 0 && magnitude >= directionalTrigger,
               let index = detentOptions.firstIndex(of: selected) {
                let nextIndex = direction > 0 ? max(index - 1, 0) : min(index + 1, detentOptions.count - 1)
                target = detentOptions[nextIndex]
            } else {
                target = detentOptions.min { lhs, rhs in
                    abs(height(for: lhs, maxHeight: adjustedMaxHeight, safeBottom: safeBottom) - projectedHeight) <
                    abs(height(for: rhs, maxHeight: adjustedMaxHeight, safeBottom: safeBottom) - projectedHeight)
                } ?? selected
            }

            withAnimation(detentAnimation) {
                selected = target
            }
        }
        .padding(.bottom, liftAmount)
        .allowsHitTesting(true)
    }

    private func height(for detent: CompactControlsDetent, maxHeight: CGFloat, safeBottom: CGFloat) -> CGFloat {
        let collapsedWithSafe = collapsedHeight + safeBottom
        switch detent {
        case .collapsed:
            return collapsedWithSafe
        case .fraction(let fraction):
            let clamped = max(0.25, min(fraction, 0.95))
            return max(collapsedWithSafe, maxHeight * clamped)
        case .medium:
            return max(collapsedWithSafe, maxHeight * 0.6)
        case .large:
            return max(collapsedWithSafe, maxHeight * 0.92)
        }
    }
}

private struct PanelBody<Content: View, BottomBar: View>: View {
    let height: CGFloat
    let collapsed: CGFloat
    let maxHeight: CGFloat
    let safeBottom: CGFloat
    let content: () -> Content
    let bottomBar: () -> BottomBar
    let dragResponsiveness: CGFloat
    let snapAnimation: Animation
    var onDragEnded: (CGFloat) -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Capsule()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .accessibilityHidden(true)

                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.bottom, contentBottomPadding)
            }

            if includesBottomBar {
                bottomBar()
                    .padding(.top, 8)
                    .padding(.bottom, bottomBarBottomPadding)
            }
        }
        .frame(height: clampedHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(
            Group {
                if #available(iOS 17.0, macOS 14.0, *) {
                    UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 22)
                        .fill(panelBackgroundColor)
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(panelBackgroundColor)
                }
            }
        )
        .overlay(
            Group {
                if #available(iOS 17.0, macOS 14.0, *) {
                    UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 22)
                        .strokeBorder(.separator.opacity(0.25), lineWidth: 0.5)
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.separator.opacity(0.25), lineWidth: 0.5)
                }
            }
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height * dragResponsiveness
                }
                .onEnded { value in
                    let offset = value.translation.height * dragResponsiveness
                    dragOffset = offset
                    onDragEnded(offset)
                    withAnimation(snapAnimation) {
                        dragOffset = 0
                    }
                }
        )
    }

    private var contentBottomPadding: CGFloat {
        includesBottomBar ? 8 : (safeBottom > 0 ? safeBottom + 10 : 16)
    }

    private var includesBottomBar: Bool {
        BottomBar.self != EmptyView.self
    }

    private var bottomBarBottomPadding: CGFloat {
        safeBottom > 0 ? safeBottom + 8 : 12
    }

    private var clampedHeight: CGFloat {
        let proposed = height - dragOffset
        let upperBound = max(collapsed, maxHeight * 0.95)
        return max(collapsed, min(upperBound, proposed))
    }

    private var panelBackgroundColor: Color {
#if os(iOS)
        Color(uiColor: .systemBackground)
#elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(uiColor: .systemBackground)
#endif
    }
}

extension CompactControlsPanel where BottomBar == EmptyView {
    init(isPresented: Binding<Bool>,
         selected: Binding<CompactControlsDetent>,
         bottomInset: CGFloat = 0,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(
            isPresented: isPresented,
            selected: selected,
            bottomInset: bottomInset,
            content: content,
            bottomBar: { EmptyView() }
        )
    }
}
