import SwiftUI

// Dots under the Friends carousel. Dots fade by 15% per step after the current page.
struct DSPageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            ForEach(0..<count, id: \.self) { index in
                let distance = abs(index - current)
                Circle()
                    .fill(DSColor.brand.opacity(max(0.1, 1 - Double(distance) * 0.15)))
                    .frame(width: distance == 0 ? 12 : 8, height: distance == 0 ? 12 : 8)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

#Preview {
    @Previewable @State var page = 0
    VStack(spacing: DSSpacing.lg) {
        DSPageIndicator(count: 7, current: page)
        Stepper("Page \(page + 1)", value: $page, in: 0...6)
    }
    .padding(DSSpacing.lg)
}
