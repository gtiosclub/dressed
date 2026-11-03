//
//  ClosetLayoutPrototype.swift
//  dressed
//
//  VIZ-P01: accessible closet browsing layout proposal (throwaway prototype).
//  Fixture data only: no fetching, no navigation.
//

import SwiftUI
 
// MARK: - Fixture models
 
enum ProtoSection {
    case pieces, outfits
}
 
enum ProtoCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case tops = "Tops"
    case pants = "Pants"
    case skirts = "Skirts"
    case shoes = "Shoes"
    var id: String { rawValue }
}
 
enum ProtoLoadState { case loaded, loading, failed }
 
enum ProtoLayout: String, CaseIterable, Identifiable {
    case grid = "Grid"
    case list = "List"
    var id: String { rawValue }
}
 
struct ProtoPiece: Identifiable, Hashable {
    let id: String
    let name: String
    let category: ProtoCategory
}
 
struct ProtoOutfit: Identifiable, Hashable {
    let id: String
    let name: String
    let pieceNames: [String]
}
 
enum ProtoFixtures {
    static let pieces: [ProtoPiece] = [
        .init(id: "p1", name: "Linen Blouse", category: .tops),
        .init(id: "p2", name: "Jeans", category: .pants),
        .init(id: "p3", name: "Pleated Midi", category: .skirts),
        .init(id: "p4", name: "Green Tee", category: .tops),
        .init(id: "p5", name: "Black Trousers", category: .pants),
        .init(id: "p6", name: "Wide Leg Pants", category: .pants),
        .init(id: "p7", name: "Denim Skirt", category: .skirts),
        .init(id: "p8", name: "White Sneakers", category: .shoes),
        .init(id: "p9", name: "Suede Loafers", category: .shoes),
    ]
 
    static let outfits: [ProtoOutfit] = [
        .init(id: "o1", name: "Weekend Casual", pieceNames: ["Green Tee", "Jeans", "White Sneakers"]),
        .init(id: "o2", name: "Office Day", pieceNames: ["Linen Blouse", "Black Trousers", "Suede Loafers"]),
        .init(id: "o3", name: "Brunch", pieceNames: ["Linen Blouse", "Pleated Midi", "White Sneakers"]),
        .init(id: "o4", name: "Errands", pieceNames: ["Green Tee", "Denim Skirt", "White Sneakers"]),
    ]
}
 
// MARK: - Inputs and callbacks leads must supply to connect real closet data
 
struct ClosetBrowseInputs {
    var pieces: [ProtoPiece]        // loaded closet pieces, unfiltered
    var outfits: [ProtoOutfit]      // loaded outfits
    var loadState: ProtoLoadState   // .loading / .loaded / .failed
}
 
struct ClosetBrowseCallbacks {
    var onSelectPiece: (ProtoPiece) -> Void = { _ in }
    var onSelectOutfit: (ProtoOutfit) -> Void = { _ in }
    var onRetry: () -> Void = {}
    var onAddPiece: () -> Void = {}
}
// Bindings the parent owns: section, category, searchText, layout.
 
// MARK: - Browse view (the proposed component)
 
struct ProtoClosetBrowseView: View {
    @Binding var section: ProtoSection
    @Binding var category: ProtoCategory
    @Binding var searchText: String
    @Binding var layout: ProtoLayout
    let inputs: ClosetBrowseInputs
    let callbacks: ClosetBrowseCallbacks
 
    @Environment(\.dynamicTypeSize) private var typeSize
 
    private var filteredPieces: [ProtoPiece] {
        inputs.pieces.filter { piece in
            (category == .all || piece.category == category) &&
            (searchText.isEmpty || piece.name.localizedCaseInsensitiveContains(searchText))
        }
    }
 
    private var isFiltering: Bool { category != .all || !searchText.isEmpty }
 
    private var columns: [GridItem] {
        if layout == .list || typeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.adaptive(minimum: 150), spacing: 16)]
    }
 
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if section == .pieces {
                searchField
                categoryControl
            }
            ScrollView {
                content.padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 20)
    }
 
    // MARK: Header
 
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top) {
                titleBlock
                Spacer(minLength: 8)
                sectionButton
            }
            VStack(alignment: .leading, spacing: 12) {
                titleBlock
                sectionButton
            }
        }
    }
 
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(section == .pieces ? "My Closet" : "My Outfits")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            if inputs.loadState == .loaded {
                Text(section == .pieces ? "\(inputs.pieces.count) items" : "\(inputs.outfits.count) outfits")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
 
    /// The "Outfits" pill: switches between the Pieces and Outfits sections.
    private var sectionButton: some View {
        Button {
            section = (section == .pieces) ? .outfits : .pieces
        } label: {
            HStack(spacing: 8) {
                Image(systemName: section == .pieces ? "hanger" : "tshirt")
                Text(section == .pieces ? "Outfits" : "Closet")
                    .font(.headline)
                if section == .pieces {
                    Text("\(inputs.outfits.count)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(minWidth: 28, minHeight: 28)
                        .background(Color.primary, in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(Color(.secondarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(section == .pieces
                            ? "Outfits, \(inputs.outfits.count) saved"
                            : "Back to closet pieces")
        .accessibilityHint(section == .pieces ? "Switches to the outfits section" : "Switches to the pieces section")
        .accessibilityAddTraits(.isButton)
    }
 
    // MARK: Search + categories
 
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search Your Closet", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 16))
    }
 
    @ViewBuilder private var categoryControl: some View {
        if typeSize.isAccessibilitySize {
            // Chip rows don't survive huge text; a menu keeps the control usable.
            Picker("Category", selection: $category) {
                ForEach(ProtoCategory.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44, alignment: .leading)
            .accessibilityLabel("Category filter")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ProtoCategory.allCases) { cat in
                        let selected = category == cat
                        Button { category = cat } label: {
                            Text(cat.rawValue)
                                .font(.body)
                                .padding(.horizontal, 20)
                                .frame(minHeight: 44)
                                .foregroundStyle(selected ? Color(.systemBackground) : Color.primary)
                                .background(selected ? Color.primary : Color(.secondarySystemFill), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(cat.rawValue)
                        .accessibilityHint("Filters pieces by category")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
    }
 
    // MARK: States
 
    @ViewBuilder private var content: some View {
        switch inputs.loadState {
        case .loading:
            loadingView
        case .failed:
            ContentUnavailableView {
                Label("Couldn't load your closet", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Something went wrong. Your items are safe.")
            } actions: {
                Button("Try again", action: callbacks.onRetry)
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
            }
        case .loaded:
            loadedContent
        }
    }
 
    @ViewBuilder private var loadedContent: some View {
        switch section {
        case .pieces:
            if inputs.pieces.isEmpty {
                ContentUnavailableView {
                    Label("No pieces yet", systemImage: "hanger")
                } description: {
                    Text("Add your first piece to start building your closet.")
                } actions: {
                    Button("Add a piece", action: callbacks.onAddPiece)
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                }
            } else if filteredPieces.isEmpty && isFiltering {
                // The filter/search is empty, NOT the closet.
                ContentUnavailableView {
                    Label("No matches", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("Your current search or filter found nothing. Your closet still has \(inputs.pieces.count) items.")
                } actions: {
                    Button("Clear search and filter") {
                        searchText = ""
                        category = .all
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                }
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(filteredPieces) { piece in
                        ProtoPieceCard(piece: piece, layout: layout) {
                            callbacks.onSelectPiece(piece)
                        }
                    }
                }
            }
        case .outfits:
            if inputs.outfits.isEmpty {
                ContentUnavailableView("No outfits yet", systemImage: "rectangle.stack",
                                       description: Text("Saved outfits will appear here."))
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(inputs.outfits) { outfit in
                        ProtoOutfitCard(outfit: outfit) { callbacks.onSelectOutfit(outfit) }
                    }
                }
            }
        }
    }
 
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemGray5))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading your closet")
    }
}
 
// MARK: - Glyphs (monochrome placeholders matching the web prototype)
 
private struct ProtoPantsShape: Shape {
    func path(in r: CGRect) -> Path {
        let pts: [(CGFloat, CGFloat)] = [(0.1, 0), (0.9, 0), (0.85, 1), (0.55, 1), (0.5, 0.35), (0.45, 1), (0.15, 1)]
        var p = Path()
        for (i, pt) in pts.enumerated() {
            let point = CGPoint(x: r.minX + pt.0 * r.width, y: r.minY + pt.1 * r.height)
            i == 0 ? p.move(to: point) : p.addLine(to: point)
        }
        p.closeSubpath()
        return p
    }
}
 
private struct ProtoSkirtShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 0.3 * r.width, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + 0.7 * r.width, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
 
private struct ProtoGlyph: View {
    let category: ProtoCategory
 
    var body: some View {
        switch category {
        case .tops, .all:
            Image(systemName: "tshirt.fill").resizable().scaledToFit().foregroundStyle(.gray)
        case .pants:
            ProtoPantsShape().fill(Color(.darkGray)).aspectRatio(0.6, contentMode: .fit)
        case .skirts:
            ProtoSkirtShape().fill(Color(.darkGray)).aspectRatio(0.8, contentMode: .fit)
        case .shoes:
            Image(systemName: "shoe.fill").resizable().scaledToFit().foregroundStyle(.gray)
        }
    }
}
 
// MARK: - Cards
 
private struct ProtoPieceCard: View {
    let piece: ProtoPiece
    let layout: ProtoLayout
    let action: () -> Void
 
    @Environment(\.dynamicTypeSize) private var typeSize
 
    private var stacked: Bool { layout == .grid || typeSize.isAccessibilitySize }
 
    var body: some View {
        Button(action: action) {
            Group {
                if stacked {
                    VStack(alignment: .leading, spacing: 8) {
                        tile.aspectRatio(1, contentMode: .fit)
                        labels
                    }
                } else {
                    HStack(spacing: 14) {
                        tile.frame(width: 72, height: 72)
                        labels
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(piece.name), \(piece.category.rawValue)")
        .accessibilityHint("Opens piece details")
        .accessibilityAddTraits(.isButton)
    }
 
    private var tile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(Color(.systemGray5))
            ProtoGlyph(category: piece.category)
                .padding(stacked ? 40 : 16)
        }
    }
 
    // Name wraps fully (no lineLimit) so long names stay readable.
    private var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(piece.name)
                .font(.headline)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(piece.category.rawValue)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
 
private struct ProtoOutfitCard: View {
    let outfit: ProtoOutfit
    let action: () -> Void
 
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(outfit.name).font(.headline)
                Text(outfit.pieceNames.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(outfit.name), \(outfit.pieceNames.count) pieces: \(outfit.pieceNames.joined(separator: ", "))")
        .accessibilityHint("Opens outfit details")
        .accessibilityAddTraits(.isButton)
    }
}
 
// MARK: - The screen alone (matches the web prototype; use for normal screenshots)
 
struct ClosetScreenOnly: View {
    @State private var section: ProtoSection = .pieces
    @State private var category: ProtoCategory = .all
    @State private var searchText = ""
    @State private var layout: ProtoLayout = .grid
 
    var body: some View {
        ProtoClosetBrowseView(
            section: $section,
            category: $category,
            searchText: $searchText,
            layout: $layout,
            inputs: .init(pieces: ProtoFixtures.pieces,
                          outfits: ProtoFixtures.outfits,
                          loadState: .loaded),
            callbacks: .init()
        )
    }
}
 
#Preview("Closet screen only") {
    ClosetScreenOnly()
}
 
// MARK: - Comparison harness (DEBUG only; widths, Dynamic Type, states)
 
#if DEBUG
struct ClosetLayoutPrototype: View {
    enum Scenario: String, CaseIterable, Identifiable {
        case populated = "Populated"
        case filteredEmpty = "Filtered empty"
        case empty = "Empty"
        case loading = "Loading"
        case failed = "Failed"
        var id: String { rawValue }
    }
 
    enum PreviewWidth: String, CaseIterable, Identifiable {
        case device = "Device"
        case phone = "375 pt"
        case tablet = "768 pt"
        case desktop = "1440 pt"
        var id: String { rawValue }
 
        /// nil = use the real available width (no simulation).
        var points: CGFloat? {
            switch self {
            case .device: return nil
            case .phone: return 375
            case .tablet: return 768
            case .desktop: return 1440
            }
        }
    }
 
    @State private var section: ProtoSection = .pieces
    @State private var category: ProtoCategory = .all
    @State private var searchText = ""
    @State private var layout: ProtoLayout = .grid
    @State private var scenario: Scenario = .populated
    @State private var width: PreviewWidth = .device
    @State private var largeText = false
    @State private var lastTapped = "Nothing tapped yet"
    @State private var showCompare = false
 
    private var inputs: ClosetBrowseInputs {
        switch scenario {
        case .populated:
            return .init(pieces: ProtoFixtures.pieces, outfits: ProtoFixtures.outfits, loadState: .loaded)
        case .filteredEmpty:
            // Supplied data has no shoes, so the Shoes filter returns nothing.
            return .init(pieces: ProtoFixtures.pieces.filter { $0.category != .shoes },
                         outfits: ProtoFixtures.outfits, loadState: .loaded)
        case .empty:
            return .init(pieces: [], outfits: [], loadState: .loaded)
        case .loading:
            return .init(pieces: [], outfits: [], loadState: .loading)
        case .failed:
            return .init(pieces: [], outfits: [], loadState: .failed)
        }
    }
 
    var body: some View {
        GeometryReader { geo in
            // Simulate a wider screen by laying out at that width, then scaling to fit.
            let target = width.points ?? geo.size.width
            let scale = min(1, geo.size.width / target)
 
            ProtoClosetBrowseView(
                section: $section,
                category: $category,
                searchText: $searchText,
                layout: $layout,
                inputs: inputs,
                callbacks: .init(
                    onSelectPiece: { lastTapped = "Tapped piece: \($0.name)" },
                    onSelectOutfit: { lastTapped = "Tapped outfit: \($0.name)" },
                    onRetry: { scenario = .populated; lastTapped = "Retry tapped, showing populated" },
                    onAddPiece: { lastTapped = "Add piece tapped" }
                )
            )
            .dynamicTypeSize(largeText ? .accessibility3 : .large)
            .frame(width: target, height: geo.size.height / scale, alignment: .top)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showCompare = true
            } label: {
                Label("Compare", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(.thinMaterial, in: Capsule())
            }
            .padding(16)
            .accessibilityHint("Opens layout comparison controls")
        }
        .sheet(isPresented: $showCompare) { compareSheet }
        .onChange(of: scenario) { _, new in
            searchText = ""
            section = .pieces
            category = (new == .filteredEmpty) ? .shoes : .all
        }
    }
 
    private var compareSheet: some View {
        NavigationStack {
            Form {
                Section("State") {
                    Picker("Scenario", selection: $scenario) {
                        ForEach(Scenario.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Layout") {
                    Picker("Layout", selection: $layout) {
                        ForEach(ProtoLayout.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Width (scaled to fit)") {
                    Picker("Width", selection: $width) {
                        ForEach(PreviewWidth.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Accessibility") {
                    Toggle("Larger Dynamic Type", isOn: $largeText)
                }
                Section("Last action") {
                    Text(lastTapped).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showCompare = false }
                }
            }
        }
        .presentationDetents([.height(380), .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .height(380)))
    }
}
 
#Preview("Comparison harness") {
    ClosetLayoutPrototype()
}
#endif
 
