import SwiftUI

/// Undo/redo controls for outfit clothing changes (`OutfitStudioModel` history).
struct OutfitUndoRedoButtons: View {
    let canUndo: Bool
    let canRedo: Bool
    let undo: () -> Void
    let redo: () -> Void

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            button(
                "TablerArrowBackUp", label: "Undo outfit change", id: "studio.undo",
                enabled: canUndo, action: undo
            )
            button(
                "TablerArrowForwardUp", label: "Redo outfit change", id: "studio.redo",
                enabled: canRedo, action: redo
            )
        }
    }

    private func button(
        _ symbol: String, label: String, id: String, enabled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            DSIcon(symbol, size: 20)
                .font(DSFont.bodyEmphasis)
                .frame(width: 43, height: 43)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

#Preview {
  OutfitUndoRedoButtons(canUndo: true, canRedo: false, undo: {}, redo: {})
}