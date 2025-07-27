import SwiftUI

struct StepIndicator: View {
    @Binding var current: Step

    var body: some View {
        HStack {
            ForEach(Step.allCases, id: \.self) { step in
                Text(step.title)
                    .fontWeight(step == current ? .bold : .regular)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(step == current ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
            }
        }
    }
}
