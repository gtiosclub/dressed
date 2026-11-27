import PhotosUI
import SwiftUI

/// Avatar settings (gear button): the full-body reference photo used to generate looks.
/// No Figma frame yet; built from the design system tokens.
struct AvatarSettingsView: View {
    @ObservedObject var model: AvatarTryOnModel
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var confirmsRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack {
                Text("Avatar Settings")
                    .font(DSFont.navTitle)
                    .foregroundStyle(DSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { dismiss() } label: { DSCloseIcon() }
                    .buttonStyle(.ds(.tile))
                    .accessibilityLabel("Close")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    preview

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(model.hasReference ? "Replace Photo" : "Upload Photo", tabler: "TablerUpload", size: 20)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ds(.primary))
                    .disabled(model.isSavingReference)
                    .accessibilityIdentifier("avatar.settings.upload")

                    if model.hasReference {
                        Button(role: .destructive) { confirmsRemove = true } label: {
                            Label("Remove Photo", tabler: "TablerTrash", size: 20)
                                .foregroundStyle(DSColor.destructive)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.ds(.text))
                    }

                    if let error = model.settingsError {
                        Text(error)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.destructive)
                    }

                }
                .padding(.bottom, DSSpacing.lg)
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.lg)
        .background(DSColor.background)
        .presentationDragIndicator(.visible)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                defer { pickerItem = nil }
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    model.settingsError = "That photo could not be loaded. Try another one."
                    return
                }
                await model.saveReference(data)
            }
        }
        .alert("Remove your photo?", isPresented: $confirmsRemove) {
            Button("Remove", role: .destructive) { model.removeReference() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your looks will be deleted too.")
        }
    }

    private var preview: some View {
        RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
            .fill(DSColor.tile)
            .aspectRatio(3 / 4, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: 340)
            .overlay {
                if let image = model.referenceImage {
                    Image(uiImage: image).resizable().scaledToFit()
                } else if model.isSavingReference {
                    ProgressView()
                } else {
                    DSIcon("TablerUser", size: 48).foregroundStyle(DSColor.iconMuted)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.hasReference ? "Your full-body photo" : "No photo yet")
            .accessibilityIdentifier("avatar.settings.preview")
    }
}

#Preview {
    AvatarSettingsView(model: AvatarTryOnModel(ownerId: nil, generator: MockAvatarImageGenerator()))
}
