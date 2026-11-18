import PhotosUI
import SwiftUI

// Development diagnostics, not an alternate sign-in or a closet-save flow.
struct RecognitionLabView: View {
    let showsImportSettings: Bool
    @StateObject private var model = RecognitionBenchmarkModel()
    @AppStorage("recognition.nativeProcessing") private var nativeImports = false
    @State private var photo: PhotosPickerItem?
    @State private var loadError: String?

    init(showsImportSettings: Bool = true) {
        self.showsImportSettings = showsImportSettings
    }

    var body: some View {
        Form {
            Section {
                Text("Compare original processing with native-pixel crops, context reuse and simpler background masking. No uploads or closet writes.")
                    .font(.footnote)
                Text("Use a real clothing photo for quality checks. Simulator Vision failures and synthetic samples cannot establish model accuracy.")
                    .font(.footnote).foregroundStyle(.secondary)
                PhotosPicker("Choose benchmark photo", selection: $photo, matching: .images)
                    .disabled(model.isRunning)
                Button("Use synthetic test image") {
                    model.select(RecognitionDemoImage.make(), kind: "Synthetic silhouette — not an accuracy sample")
                }.disabled(model.isRunning)
                if let data = model.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 100)
                    Text(model.sampleKind).font(.caption)
                }
            }
            Section("Compare") {
                if showsImportSettings {
                    Toggle("Use native processing in imports (trial)", isOn: $nativeImports)
                        .disabled(model.isRunning)
                    Text("Keep this off until a phone comparison passes speed and quality checks. This switch affects imports; comparisons always test both paths.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Picker("Trial", selection: $model.variant) {
                    Text("Native pixels + reuse").tag(RecognitionMode.nativePixels)
                    Text("1024px + reuse (quality trial)").tag(RecognitionMode.compact)
                }.disabled(model.isRunning)
                Stepper("Repeated pairs: \(model.repetitions)", value: $model.repetitions, in: 1...5)
                    .disabled(model.isRunning)
                Button("Run comparison", action: model.start)
                    .disabled(model.imageData == nil || model.isRunning)
                if model.isRunning {
                    ProgressView()
                    Button("Stop comparison", action: model.cancel)
                }
                Text(model.progress).accessibilityIdentifier("recognition.progress")
                if let loadError { Text(loadError).foregroundStyle(.red) }
            }
            if !model.entries.isEmpty {
                Section("Measured wall time") {
                    Text("First-use runs are shown separately and excluded from medians. Totals include recognition and cutouts, not saving. Stage totals can overlap.")
                        .font(.footnote)
                    ForEach([RecognitionMode.baseline, model.variant]) { mode in
                        HStack {
                            Text(mode.title)
                            Spacer()
                            Text(model.median(for: mode).map { String(format: "%.0f ms median", $0) } ?? "First run only")
                        }
                    }
                    ForEach(Array(model.entries.enumerated()), id: \.offset) { _, entry in
                        DisclosureGroup("\(entry.result.mode.title) · \(entry.firstRun ? "first" : "repeat \(entry.repetition)") · \(Int(entry.result.milliseconds)) ms") {
                            ForEach(Array(entry.result.stages.enumerated()), id: \.offset) { _, stage in
                                Text("\(stage.name): \(Int(stage.milliseconds)) ms").font(.caption.monospacedDigit())
                            }
                            Text("\(entry.result.cutoutCount) cutouts · \(entry.result.outputBytes) output bytes")
                                .font(.caption)
                            ForEach(entry.result.warnings, id: \.self) { Text($0).foregroundStyle(.orange) }
                        }
                    }
                    if let file = model.exportURL {
                        ShareLink("Export timing JSON (no photos)", item: file)
                    }
                }
                ForEach([RecognitionMode.baseline, model.variant]) { mode in
                    if let run = model.latest[mode] {
                        Section("\(mode.title) quality preview") {
                            ForEach(run.candidates) { candidate in
                                Text("\(candidate.name) · \(candidate.category.rawValue)")
                                if let data = run.cutouts[candidate.id], let image = UIImage(data: data) {
                                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                                } else { Text("No cutout; keep the original/manual fallback.").font(.caption) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("On-device speed test")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photo) { _, selected in
            Task {
                do {
                    guard let data = try await selected?.loadTransferable(type: Data.self) else { return }
                    model.select(data, kind: "Chosen development photo")
                    loadError = nil
                } catch { loadError = "The photo could not be opened." }
            }
        }
        .task {
            model.selectDevelopmentInputIfRequested()
            if ProcessInfo.processInfo.arguments.contains("-syntheticRecognition") {
                model.select(RecognitionDemoImage.make(), kind: "Synthetic silhouette — not an accuracy sample")
                let args = ProcessInfo.processInfo.arguments
                if let index = args.firstIndex(of: "-benchmarkRepeats"), index + 1 < args.count,
                   let count = Int(args[index + 1]) { model.repetitions = min(5, max(1, count)) }
                else { model.repetitions = 1 }
                if ProcessInfo.processInfo.arguments.contains("-runRecognitionBenchmark") { model.start() }
            }
        }
        .onDisappear { model.cancel() }
    }
}
