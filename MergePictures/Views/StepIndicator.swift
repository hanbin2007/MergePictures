import SwiftUI

struct StepIndicator: View {
    @Binding var current: Step
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack {
            ForEach(Step.allCases, id: \.self) { step in
                let enabled = isStepEnabled(step)
                Button {
                    current = step
                } label: {
                    Text(LocalizedStringKey(step.title))
                        .fontWeight(step == current ? .bold : .regular)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(step == current ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                        .opacity(enabled ? 1.0 : 0.4) // grayed out when disabled
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
            }
        }
    }

    private func isStepEnabled(_ step: Step) -> Bool {
        // 初始状态：仅 Select 可点击
        if viewModel.images.isEmpty { return step == .selectImages }

        // 已在预览后：全部可点击
        if viewModel.stepIndicatorUnlockedAll { return true }

        // 已添加图片但未进入预览：Select 与 Preview 可点击（Export 禁用）
        return step == .selectImages || step == .previewAll
    }
}
