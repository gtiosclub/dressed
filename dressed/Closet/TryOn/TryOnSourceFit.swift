import UIKit

/// Where a garment sat on the person in the upload photo.
/// Coordinates are normalized to that photo, with the origin at the top left.
struct TryOnSourceFit: Codable, Equatable {
    var landmarks: TryOnLandmarks
    var garmentBounds: TryOnRect
    /// Body point the garment's lower edge lines up with: waist, hips, knees, or feet.
    var hemLandmark: String
    var hemPoint: TryOnPoint
    var shoulderPoint: TryOnPoint
    /// The closet image is the garment cutout filling `garmentBounds`.
    /// When false, the closet image is the full worn photo and the garment is the bounds rectangle.
    var cutoutFillsBounds: Bool
    var gridColumns: Int
    var gridRows: Int
    /// One entry per square. `landmark` is neck, shoulder, elbow, wrist, waist, hip, knee, foot, or empty.
    var squares: [TryOnGarmentSquare]

    var hemDescription: String {
        switch hemLandmark {
        case "waistCenter", "waist": return "waist"
        case "leftHip", "hip": return "hips"
        case "leftKnee", "knee": return "knees"
        case "leftAnkle", "foot": return "feet"
        default: return hemLandmark
        }
    }

    var recordedDescription: String {
        let names = TryOnSourceFit.detectedNames(in: landmarks)
        return names.isEmpty ? "no body points" : names.joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case landmarks, garmentBounds, hemLandmark, hemPoint, shoulderPoint
        case cutoutFillsBounds, gridColumns, gridRows, squares
    }

    init(
        landmarks: TryOnLandmarks,
        garmentBounds: TryOnRect,
        hemLandmark: String,
        hemPoint: TryOnPoint,
        shoulderPoint: TryOnPoint,
        cutoutFillsBounds: Bool,
        gridColumns: Int,
        gridRows: Int,
        squares: [TryOnGarmentSquare]
    ) {
        self.landmarks = landmarks
        self.garmentBounds = garmentBounds
        self.hemLandmark = hemLandmark
        self.hemPoint = hemPoint
        self.shoulderPoint = shoulderPoint
        self.cutoutFillsBounds = cutoutFillsBounds
        self.gridColumns = gridColumns
        self.gridRows = gridRows
        self.squares = squares
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        landmarks = try container.decode(TryOnLandmarks.self, forKey: .landmarks)
        garmentBounds = try container.decode(TryOnRect.self, forKey: .garmentBounds)
        hemLandmark = try container.decode(String.self, forKey: .hemLandmark)
        hemPoint = try container.decode(TryOnPoint.self, forKey: .hemPoint)
        shoulderPoint = try container.decode(TryOnPoint.self, forKey: .shoulderPoint)
        cutoutFillsBounds = try container.decodeIfPresent(Bool.self, forKey: .cutoutFillsBounds) ?? true
        gridColumns = try container.decodeIfPresent(Int.self, forKey: .gridColumns) ?? 0
        gridRows = try container.decodeIfPresent(Int.self, forKey: .gridRows) ?? 0
        squares = try container.decodeIfPresent([TryOnGarmentSquare].self, forKey: .squares) ?? []
    }
}

struct TryOnGarmentSquare: Codable, Equatable {
    var column: Int
    var row: Int
    var landmark: String
    var source: TryOnRect
}

struct TryOnPlacement {
    var image: CGImage
    var mesh: TryOnMesh
}

enum TryOnSourceFitStore {
    /// Measures the original worn photo. Returns a specific reason when coordinates are not saved.
    /// The closet image may be only the cutout; pose is never run on that cutout.
    @discardableResult
    static func capture(
        ownerId: String,
        itemID: String,
        photo: Data,
        region: NormalizedImageRegion?,
        outline: [NormalizedImagePoint]?,
        category: ClothingCategory,
        cutoutFillsBounds: Bool
    ) -> String? {
        guard let image = UIImage(data: photo) else {
            return fail(ownerId: ownerId, itemID: itemID, "The worn photo could not be opened, so shoulder, waist, hip, knee, and foot coordinates were not recorded.")
        }
        guard let upright = upright(image) else {
            return fail(ownerId: ownerId, itemID: itemID, "The worn photo could not be read, so shoulder, waist, hip, knee, and foot coordinates were not recorded.")
        }
        switch TryOnSourceFit.measure(
            photo: upright,
            region: region,
            outline: outline,
            category: category,
            cutoutFillsBounds: cutoutFillsBounds
        ) {
        case .fit(let fit):
            do {
                try save(fit, ownerId: ownerId, itemID: itemID)
                try? FileManager.default.removeItem(at: failureFile(ownerId: ownerId, itemID: itemID))
                return nil
            } catch {
                return fail(ownerId: ownerId, itemID: itemID, "Body coordinates were measured but could not be saved. Add the photo of the person wearing the piece again.")
            }
        case .failed(let reason):
            return fail(ownerId: ownerId, itemID: itemID, reason)
        }
    }

    static func load(ownerId: String, itemID: String) -> TryOnSourceFit? {
        guard let data = try? Data(contentsOf: file(ownerId: ownerId, itemID: itemID)) else { return nil }
        return try? JSONDecoder().decode(TryOnSourceFit.self, from: data)
    }

    static func failureReason(ownerId: String, itemID: String) -> String? {
        guard let data = try? Data(contentsOf: failureFile(ownerId: ownerId, itemID: itemID)),
              let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    static func save(_ fit: TryOnSourceFit, ownerId: String, itemID: String) throws {
        let url = file(ownerId: ownerId, itemID: itemID)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(fit).write(to: url, options: .atomic)
    }

    private static func fail(ownerId: String, itemID: String, _ reason: String) -> String {
        try? FileManager.default.removeItem(at: file(ownerId: ownerId, itemID: itemID))
        let url = failureFile(ownerId: ownerId, itemID: itemID)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(reason.utf8).write(to: url, options: .atomic)
        return reason
    }

    private static func file(ownerId: String, itemID: String) -> URL {
        directory(ownerId: ownerId, itemID: itemID).appendingPathExtension("json")
    }

    private static func failureFile(ownerId: String, itemID: String) -> URL {
        directory(ownerId: ownerId, itemID: itemID).appendingPathExtension("failure.txt")
    }

    private static func directory(ownerId: String, itemID: String) -> URL {
        let safeOwner = ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        let owner = safeOwner.isEmpty ? "local" : safeOwner.replacingOccurrences(of: "/", with: "_")
        let safeItem = itemID.replacingOccurrences(of: "/", with: "_")
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrototypeCloset", isDirectory: true)
            .appendingPathComponent(owner, isDirectory: true)
            .appendingPathComponent("fit", isDirectory: true)
            .appendingPathComponent(safeItem)
    }

    static func upright(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage { return cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return rendered.cgImage
    }
}

private enum TryOnMeasureOutcome {
    case fit(TryOnSourceFit)
    case failed(String)
}

private struct TryOnBodyLevel {
    var name: String
    var center: TryOnPoint
    var left: TryOnPoint
    var right: TryOnPoint
}

extension TryOnSourceFit {
    /// Reads the person in the worn photo and divides the garment into landmark squares.
    fileprivate static func measure(
        photo: CGImage,
        region: NormalizedImageRegion?,
        outline: [NormalizedImagePoint]?,
        category: ClothingCategory,
        cutoutFillsBounds: Bool
    ) -> TryOnMeasureOutcome {
        let analysis = TryOnVision.analyze(photo)
        let landmarks = completed(analysis.landmarks)
        let detected = detectedNames(in: landmarks)
        guard !detected.isEmpty else {
            return .failed("No person was detected in the worn photo, so there are no shoulder, waist, hip, knee, or foot coordinates. Use a photo that shows the person wearing the piece, not only the cutout.")
        }
        let levels = bodyLevels(in: landmarks)
        guard levels.count >= 2 else {
            return .failed("The worn photo only shows \(detected.joined(separator: ", ")). At least two of neck, shoulders, elbows, wrists, waist, hips, knees, and feet are needed to place the piece.")
        }
        guard let bounds = garmentBounds(
            region: region,
            outline: outline,
            photo: photo,
            landmarks: landmarks,
            silhouette: analysis.silhouette,
            category: category,
            cutoutFillsBounds: cutoutFillsBounds
        ) else {
            return .failed("A person was detected (\(detected.joined(separator: ", "))), but the garment area in the worn photo could not be measured.")
        }
        let grid = gridSize(for: bounds)
        let squares = buildSquares(bounds: bounds, columns: grid.columns, rows: grid.rows, levels: levels)
        guard squares.contains(where: { $0.landmark != "empty" }) else {
            return .failed("The garment area does not cover the detected body (\(detected.joined(separator: ", "))), so the piece could not be placed.")
        }
        let hem = hemAnchor(bounds: bounds, landmarks: landmarks, levels: levels)
        let shoulder = topAnchor(in: landmarks, levels: levels)
        return .fit(TryOnSourceFit(
            landmarks: landmarks,
            garmentBounds: bounds,
            hemLandmark: hem.name,
            hemPoint: hem.point,
            shoulderPoint: shoulder,
            cutoutFillsBounds: cutoutFillsBounds,
            gridColumns: grid.columns,
            gridRows: grid.rows,
            squares: squares
        ))
    }

    /// Draws the cutout by mapping each square onto the same body landmarks on the avatar.
    /// Does not regenerate the garment artwork.
    static func place(cutout: UIImage, fit: TryOnSourceFit, avatar: TryOnLandmarks, canvas: TryOnCanvas) -> TryOnPlacement? {
        guard let sourceImage = TryOnSourceFitStore.upright(cutout),
              let source = TryOnBitmap.rgba(from: sourceImage) else { return nil }
        let squares = resolvedSquares(fit)
        let sourceLevels = bodyLevels(in: fit.landmarks)
        let avatarLevels = bodyLevels(in: avatar)
        let shared = sharedLevels(sourceLevels, avatarLevels)
        guard shared.source.count >= 2 else { return nil }
        let columns = max(fit.gridColumns, gridSize(for: fit.garmentBounds).columns)
        let rows = max(fit.gridRows, gridSize(for: fit.garmentBounds).rows)
        var output = [UInt8](repeating: 0, count: canvas.width * canvas.height * 4)
        var drawable = Array(repeating: false, count: columns * rows)
        var corners = Array(repeating: TryOnPoint.zero, count: (columns + 1) * (rows + 1))
        for row in 0...rows {
            for column in 0...columns {
                let photoPoint = gridPoint(column: column, row: row, columns: columns, rows: rows, bounds: fit.garmentBounds)
                corners[row * (columns + 1) + column] = map(photoPoint, from: shared.source, to: shared.avatar).clampedToCanvas()
            }
        }
        var drew = false
        for square in squares where square.column < columns && square.row < rows {
            let index = square.row * columns + square.column
            let photo = cellCorners(square)
            let uvs = photo.map { cutoutUV($0, fit: fit) }
            if square.landmark == "empty" || cellIsTransparent(uvs, source: source) {
                continue
            }
            drawable[index] = true
            let dest = (0..<4).map { offset -> TryOnPoint in
                let column = square.column + (offset == 1 || offset == 2 ? 1 : 0)
                let row = square.row + (offset >= 2 ? 1 : 0)
                return corners[row * (columns + 1) + column]
            }
            let painted = paint(
                dest[0], dest[1], dest[2], uvs[0], uvs[1], uvs[2],
                source: source, into: &output, canvas: canvas
            )
            let paintedOther = paint(
                dest[0], dest[2], dest[3], uvs[0], uvs[2], uvs[3],
                source: source, into: &output, canvas: canvas
            )
            drew = drew || painted || paintedOther
        }
        guard drew, let image = TryOnBitmap.cgImage(width: canvas.width, height: canvas.height, bytes: output) else {
            return nil
        }
        let mesh = meshFrom(
            corners: corners,
            drawable: drawable,
            columns: columns,
            rows: rows,
            sourceLevels: shared.source,
            avatarLevels: shared.avatar,
            bounds: fit.garmentBounds
        )
        guard !mesh.indices.isEmpty else { return nil }
        return TryOnPlacement(image: image, mesh: mesh)
    }

    static func placementFailure(fit: TryOnSourceFit, avatar: TryOnLandmarks) -> String {
        let source = bodyLevels(in: fit.landmarks)
        let target = bodyLevels(in: avatar)
        let shared = sharedLevels(source, target)
        if shared.source.count >= 2 {
            return "The garment cutout is empty, so it could not be placed on the avatar."
        }
        let missing = source.map(\.name).filter { name in !target.contains { $0.name == name } }
        if missing.isEmpty {
            return "The avatar does not have enough body points to place this piece. The worn photo recorded \(fit.recordedDescription)."
        }
        return "The avatar is missing \(englishList(missing.map(levelLabel))) points, so this piece cannot be placed. The worn photo recorded \(fit.recordedDescription)."
    }

    static func bodyPoint(_ name: String, in landmarks: TryOnLandmarks) -> TryOnPoint? {
        switch name {
        case "leftHip", "hip":
            return midpoint(landmarks.leftHip, landmarks.rightHip) ?? landmarks.leftHip ?? landmarks.rightHip
        case "leftKnee", "knee":
            return midpoint(landmarks.leftKnee, landmarks.rightKnee) ?? landmarks.leftKnee ?? landmarks.rightKnee
        case "leftAnkle", "foot":
            return midpoint(landmarks.leftAnkle, landmarks.rightAnkle) ?? landmarks.leftAnkle ?? landmarks.rightAnkle
        case "shoulder":
            return midpoint(landmarks.leftShoulderJoint, landmarks.rightShoulderJoint)
                ?? landmarks.leftShoulderJoint ?? landmarks.rightShoulderJoint
        case "elbow":
            return midpoint(landmarks.leftElbow, landmarks.rightElbow) ?? landmarks.leftElbow ?? landmarks.rightElbow
        case "wrist":
            return midpoint(landmarks.leftWrist, landmarks.rightWrist) ?? landmarks.leftWrist ?? landmarks.rightWrist
        case "waist":
            return landmarks.waistCenter
        case "neck":
            return landmarks.neckCenter
        default:
            return landmarks.point(named: name)
        }
    }

    static func detectedNames(in landmarks: TryOnLandmarks) -> [String] {
        var names: [String] = []
        if landmarks.neckCenter != nil { names.append("neck") }
        if landmarks.leftShoulderJoint != nil || landmarks.rightShoulderJoint != nil { names.append("shoulders") }
        if landmarks.leftElbow != nil || landmarks.rightElbow != nil { names.append("elbows") }
        if landmarks.leftWrist != nil || landmarks.rightWrist != nil { names.append("wrists") }
        if landmarks.waistCenter != nil || landmarks.leftWaist != nil || landmarks.rightWaist != nil { names.append("waist") }
        if landmarks.leftHip != nil || landmarks.rightHip != nil { names.append("hips") }
        if landmarks.leftKnee != nil || landmarks.rightKnee != nil { names.append("knees") }
        if landmarks.leftAnkle != nil || landmarks.rightAnkle != nil { names.append("feet") }
        return names
    }

    static func gridSize(for bounds: TryOnRect) -> (columns: Int, rows: Int) {
        let small = min(bounds.width, bounds.height) < 0.2
        return small ? (4, 4) : (8, 8)
    }

    private static func resolvedSquares(_ fit: TryOnSourceFit) -> [TryOnGarmentSquare] {
        if !fit.squares.isEmpty { return fit.squares }
        let grid = gridSize(for: fit.garmentBounds)
        return buildSquares(
            bounds: fit.garmentBounds,
            columns: grid.columns,
            rows: grid.rows,
            levels: bodyLevels(in: fit.landmarks)
        )
    }

    private static func garmentBounds(
        region: NormalizedImageRegion?,
        outline: [NormalizedImagePoint]?,
        photo: CGImage,
        landmarks: TryOnLandmarks,
        silhouette: CGImage?,
        category: ClothingCategory,
        cutoutFillsBounds: Bool
    ) -> TryOnRect? {
        if let explicit = explicitBounds(region: region, outline: outline) { return explicit }
        if cutoutFillsBounds, let foreground = aligned(TryOnVision.foregroundBounds(photo), to: landmarks) {
            return foreground
        }
        if !cutoutFillsBounds, let categoryRect = categoryBounds(category, landmarks: landmarks) {
            return categoryRect
        }
        if let person = aligned(maskBounds(silhouette), to: landmarks) { return person }
        return span(allPoints(landmarks), pad: 0.04)
    }

    private static func explicitBounds(region: NormalizedImageRegion?, outline: [NormalizedImagePoint]?) -> TryOnRect? {
        if let outline, outline.count >= 3, outline.allSatisfy(\.isValid) {
            let xs = outline.map(\.x)
            let ys = outline.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max(),
                  maxX - minX >= 0.01, maxY - minY >= 0.01 else { return nil }
            return TryOnRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
        guard let region, region.isValid else { return nil }
        return TryOnRect(x: region.x, y: region.y, width: region.width, height: region.height)
    }

    private static func categoryBounds(_ category: ClothingCategory, landmarks: TryOnLandmarks) -> TryOnRect? {
        switch category {
        case .pants:
            return span([
                landmarks.waistCenter, landmarks.leftWaist, landmarks.rightWaist,
                landmarks.leftHip, landmarks.rightHip, landmarks.leftKnee, landmarks.rightKnee,
                landmarks.leftAnkle, landmarks.rightAnkle
            ], pad: 0.05)
        case .skirts:
            return span([
                landmarks.waistCenter, landmarks.leftWaist, landmarks.rightWaist,
                landmarks.leftHip, landmarks.rightHip, landmarks.leftKnee, landmarks.rightKnee
            ], pad: 0.05)
        case .shoes:
            return span([landmarks.leftAnkle, landmarks.rightAnkle], pad: 0.06)
        case .tops, .outerwear, .accessories:
            return span([
                landmarks.neckCenter, landmarks.leftShoulderJoint, landmarks.rightShoulderJoint,
                landmarks.leftElbow, landmarks.rightElbow, landmarks.leftWrist, landmarks.rightWrist,
                landmarks.waistCenter, landmarks.leftHip, landmarks.rightHip
            ], pad: 0.04)
        case .dresses:
            return span([
                landmarks.neckCenter, landmarks.leftShoulderJoint, landmarks.rightShoulderJoint,
                landmarks.waistCenter, landmarks.leftHip, landmarks.rightHip,
                landmarks.leftKnee, landmarks.rightKnee, landmarks.leftAnkle, landmarks.rightAnkle
            ], pad: 0.04)
        case .other:
            return nil
        }
    }

    private static func completed(_ landmarks: TryOnLandmarks) -> TryOnLandmarks {
        var copy = landmarks
        let known = allPoints(copy)
        let centerX = known.isEmpty ? 0.5 : known.map(\.x).reduce(0, +) / Double(known.count)
        func mirror(_ left: inout TryOnPoint?, _ right: inout TryOnPoint?) {
            if let left, right == nil {
                right = TryOnPoint(x: centerX - (left.x - centerX), y: left.y)
            } else if let right, left == nil {
                left = TryOnPoint(x: centerX - (right.x - centerX), y: right.y)
            }
        }
        mirror(&copy.leftShoulderJoint, &copy.rightShoulderJoint)
        mirror(&copy.leftElbow, &copy.rightElbow)
        mirror(&copy.leftWrist, &copy.rightWrist)
        mirror(&copy.leftHip, &copy.rightHip)
        mirror(&copy.leftKnee, &copy.rightKnee)
        mirror(&copy.leftAnkle, &copy.rightAnkle)
        mirror(&copy.leftWaist, &copy.rightWaist)
        mirror(&copy.leftShoulderEdge, &copy.rightShoulderEdge)
        return TryOnVision.derived(copy)
    }

    private static func hemAnchor(
        bounds: TryOnRect,
        landmarks: TryOnLandmarks,
        levels: [TryOnBodyLevel]
    ) -> (name: String, point: TryOnPoint) {
        let bottom = bounds.y + bounds.height
        let candidates: [(String, TryOnPoint)] = [
            ("waistCenter", landmarks.waistCenter),
            ("leftHip", bodyPoint("hip", in: landmarks)),
            ("leftKnee", bodyPoint("knee", in: landmarks)),
            ("leftAnkle", bodyPoint("foot", in: landmarks))
        ].compactMap { name, point in
            guard let point else { return nil }
            return (name, point)
        }
        if let hem = candidates.min(by: { abs($0.1.y - bottom) < abs($1.1.y - bottom) }) {
            return (hem.0, hem.1)
        }
        let lowest = levels.max(by: { $0.center.y < $1.center.y }) ?? levels[0]
        return (lowest.name, lowest.center)
    }

    private static func topAnchor(in landmarks: TryOnLandmarks, levels: [TryOnBodyLevel]) -> TryOnPoint {
        bodyPoint("shoulder", in: landmarks)
            ?? landmarks.neckCenter
            ?? landmarks.waistCenter
            ?? bodyPoint("hip", in: landmarks)
            ?? levels[0].center
    }

    fileprivate static func bodyLevels(in landmarks: TryOnLandmarks) -> [TryOnBodyLevel] {
        var levels: [TryOnBodyLevel] = []
        func add(_ name: String, _ left: TryOnPoint?, _ right: TryOnPoint?, _ center: TryOnPoint?, width: Double) {
            let resolvedLeft: TryOnPoint
            let resolvedRight: TryOnPoint
            let resolvedCenter: TryOnPoint
            if let left, let right {
                resolvedLeft = left.x <= right.x ? left : right
                resolvedRight = left.x <= right.x ? right : left
                resolvedCenter = center ?? TryOnPoint(
                    x: (resolvedLeft.x + resolvedRight.x) / 2,
                    y: (resolvedLeft.y + resolvedRight.y) / 2
                )
            } else if let center {
                let half = max(width, 0.03)
                resolvedCenter = center
                resolvedLeft = TryOnPoint(x: center.x - half, y: center.y)
                resolvedRight = TryOnPoint(x: center.x + half, y: center.y)
            } else if let only = left ?? right {
                let half = max(width, 0.03)
                resolvedCenter = only
                resolvedLeft = TryOnPoint(x: only.x - half, y: only.y)
                resolvedRight = TryOnPoint(x: only.x + half, y: only.y)
            } else {
                return
            }
            guard abs(resolvedRight.x - resolvedLeft.x) > 0.01 else { return }
            levels.append(TryOnBodyLevel(name: name, center: resolvedCenter, left: resolvedLeft, right: resolvedRight))
        }
        let shoulderWidth = abs((landmarks.rightShoulderJoint?.x ?? 0) - (landmarks.leftShoulderJoint?.x ?? 0))
        let hipWidth = abs((landmarks.rightHip?.x ?? 0) - (landmarks.leftHip?.x ?? 0))
        let reference = max(shoulderWidth, hipWidth, 0.08)
        add("neck", nil, nil, landmarks.neckCenter, width: reference * 0.22)
        add("shoulder", landmarks.leftShoulderJoint, landmarks.rightShoulderJoint, bodyPoint("shoulder", in: landmarks), width: reference)
        add("elbow", landmarks.leftElbow, landmarks.rightElbow, bodyPoint("elbow", in: landmarks), width: reference * 1.2)
        add("wrist", landmarks.leftWrist, landmarks.rightWrist, bodyPoint("wrist", in: landmarks), width: reference * 1.3)
        add("waist", landmarks.leftWaist, landmarks.rightWaist, landmarks.waistCenter, width: max(hipWidth, reference * 0.7))
        add("hip", landmarks.leftHip, landmarks.rightHip, bodyPoint("hip", in: landmarks), width: reference)
        add("knee", landmarks.leftKnee, landmarks.rightKnee, bodyPoint("knee", in: landmarks), width: max(hipWidth * 0.8, 0.08))
        add("foot", landmarks.leftAnkle, landmarks.rightAnkle, bodyPoint("foot", in: landmarks), width: max(hipWidth * 0.7, 0.08))
        return levels.sorted { $0.center.y < $1.center.y }
    }

    private static func sharedLevels(
        _ source: [TryOnBodyLevel],
        _ avatar: [TryOnBodyLevel]
    ) -> (source: [TryOnBodyLevel], avatar: [TryOnBodyLevel]) {
        let names = source.map(\.name).filter { name in avatar.contains { $0.name == name } }
        let sourceLevels = names.compactMap { name in source.first { $0.name == name } }
        let avatarLevels = names.compactMap { name in avatar.first { $0.name == name } }
        return (sourceLevels, avatarLevels)
    }

    private static func map(_ point: TryOnPoint, from source: [TryOnBodyLevel], to avatar: [TryOnBodyLevel]) -> TryOnPoint {
        guard source.count >= 2, avatar.count == source.count else { return point }
        let (upper, lower, t) = bracket(point.y, source)
        guard let avatarUpper = avatar.first(where: { $0.name == upper.name }),
              let avatarLower = avatar.first(where: { $0.name == lower.name }) else { return point }
        let left = lerp(upper.left.x, lower.left.x, t)
        let right = lerp(upper.right.x, lower.right.x, t)
        let span = right - left
        let s = abs(span) > 0.02 ? (point.x - left) / span : 0.5
        let avatarLeft = lerp(avatarUpper.left.x, avatarLower.left.x, t)
        let avatarRight = lerp(avatarUpper.right.x, avatarLower.right.x, t)
        return TryOnPoint(
            x: avatarLeft + s * (avatarRight - avatarLeft),
            y: lerp(avatarUpper.center.y, avatarLower.center.y, t)
        )
    }

    private static func bracket(_ y: Double, _ levels: [TryOnBodyLevel]) -> (TryOnBodyLevel, TryOnBodyLevel, Double) {
        if y <= levels[0].center.y { return (levels[0], levels[1], 0) }
        let last = levels.count - 1
        if y >= levels[last].center.y { return (levels[last - 1], levels[last], 1) }
        for index in 0..<last {
            let upper = levels[index]
            let lower = levels[index + 1]
            if y >= upper.center.y && y <= lower.center.y {
                let span = lower.center.y - upper.center.y
                let t = span > 0.001 ? (y - upper.center.y) / span : 0
                return (upper, lower, t)
            }
        }
        return (levels[0], levels[1], 0)
    }

    private static func buildSquares(
        bounds: TryOnRect,
        columns: Int,
        rows: Int,
        levels: [TryOnBodyLevel]
    ) -> [TryOnGarmentSquare] {
        var squares: [TryOnGarmentSquare] = []
        for row in 0..<rows {
            for column in 0..<columns {
                let rect = TryOnRect(
                    x: bounds.x + bounds.width * Double(column) / Double(columns),
                    y: bounds.y + bounds.height * Double(row) / Double(rows),
                    width: bounds.width / Double(columns),
                    height: bounds.height / Double(rows)
                )
                squares.append(TryOnGarmentSquare(
                    column: column,
                    row: row,
                    landmark: classify(rect, levels: levels),
                    source: rect
                ))
            }
        }
        return squares
    }

    private static func classify(_ rect: TryOnRect, levels: [TryOnBodyLevel]) -> String {
        let probes: [(String, TryOnPoint)] = levels.flatMap { level in
            [(level.name, level.center), (level.name, level.left), (level.name, level.right)]
        }
        let center = rect.center
        var best: (String, Double)?
        for probe in probes where rect.contains(probe.1) {
            let distance = hypot(probe.1.x - center.x, probe.1.y - center.y)
            if best == nil || distance < best!.1 { best = (probe.0, distance) }
        }
        if let best { return best.0 }
        guard levels.count >= 2 else { return levels.first?.name ?? "empty" }
        if outsideBody(center, levels: levels) { return "empty" }
        let (upper, lower, t) = bracket(center.y, levels)
        return t < 0.5 ? upper.name : lower.name
    }

    private static func outsideBody(_ point: TryOnPoint, levels: [TryOnBodyLevel]) -> Bool {
        guard levels.count >= 2 else { return false }
        let (upper, lower, t) = bracket(point.y, levels)
        let left = lerp(upper.left.x, lower.left.x, t)
        let right = lerp(upper.right.x, lower.right.x, t)
        let pad = max(0.03, abs(right - left) * 0.45)
        return point.x < min(left, right) - pad || point.x > max(left, right) + pad
    }

    private static func gridPoint(column: Int, row: Int, columns: Int, rows: Int, bounds: TryOnRect) -> TryOnPoint {
        TryOnPoint(
            x: bounds.x + bounds.width * Double(column) / Double(columns),
            y: bounds.y + bounds.height * Double(row) / Double(rows)
        )
    }

    private static func cellCorners(_ square: TryOnGarmentSquare) -> [TryOnPoint] {
        let rect = square.source
        return [
            TryOnPoint(x: rect.x, y: rect.y),
            TryOnPoint(x: rect.x + rect.width, y: rect.y),
            TryOnPoint(x: rect.x + rect.width, y: rect.y + rect.height),
            TryOnPoint(x: rect.x, y: rect.y + rect.height)
        ]
    }

    private static func cutoutUV(_ photo: TryOnPoint, fit: TryOnSourceFit) -> TryOnPoint {
        guard fit.cutoutFillsBounds else { return photo }
        let bounds = fit.garmentBounds
        return TryOnPoint(
            x: (photo.x - bounds.x) / max(bounds.width, 0.0001),
            y: (photo.y - bounds.y) / max(bounds.height, 0.0001)
        )
    }

    private static func cellIsTransparent(
        _ uvs: [TryOnPoint],
        source: (width: Int, height: Int, bytes: [UInt8])
    ) -> Bool {
        guard uvs.count == 4 else { return true }
        var opaque = 0
        var samples = 0
        for row in 0..<3 {
            for column in 0..<3 {
                let u = (uvs[0].x * Double(2 - column) + uvs[1].x * Double(column)) / 2
                let vTop = (uvs[0].y * Double(2 - column) + uvs[1].y * Double(column)) / 2
                let vBottom = (uvs[3].y * Double(2 - column) + uvs[2].y * Double(column)) / 2
                let uTop = u
                let uBottom = (uvs[3].x * Double(2 - column) + uvs[2].x * Double(column)) / 2
                let sampleU = (uTop * Double(2 - row) + uBottom * Double(row)) / 2
                let sampleV = (vTop * Double(2 - row) + vBottom * Double(row)) / 2
                samples += 1
                if sampleAlpha(sampleU, sampleV, source: source) > 16 { opaque += 1 }
            }
        }
        return samples == 0 || opaque < 2
    }

    private static func sampleAlpha(
        _ u: Double,
        _ v: Double,
        source: (width: Int, height: Int, bytes: [UInt8])
    ) -> UInt8 {
        guard source.width > 1, source.height > 1, u >= 0, v >= 0, u <= 1, v <= 1 else { return 0 }
        let x = min(source.width - 1, max(0, Int((u * Double(source.width - 1)).rounded())))
        let y = min(source.height - 1, max(0, Int((v * Double(source.height - 1)).rounded())))
        return source.bytes[(y * source.width + x) * 4 + 3]
    }

    @discardableResult
    private static func paint(
        _ a: TryOnPoint, _ b: TryOnPoint, _ c: TryOnPoint,
        _ ua: TryOnPoint, _ ub: TryOnPoint, _ uc: TryOnPoint,
        source: (width: Int, height: Int, bytes: [UInt8]),
        into output: inout [UInt8],
        canvas: TryOnCanvas
    ) -> Bool {
        let den = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
        guard abs(den) > 1e-8 else { return false }
        let width = canvas.width
        let height = canvas.height
        let minX = max(Int((min(a.x, min(b.x, c.x)) * Double(width)).rounded(.down)), 0)
        let maxX = min(Int((max(a.x, max(b.x, c.x)) * Double(width)).rounded(.up)), width - 1)
        let minY = max(Int((min(a.y, min(b.y, c.y)) * Double(height)).rounded(.down)), 0)
        let maxY = min(Int((max(a.y, max(b.y, c.y)) * Double(height)).rounded(.up)), height - 1)
        guard minX <= maxX, minY <= maxY else { return false }
        var painted = false
        for y in minY...maxY {
            for x in minX...maxX {
                let px = (Double(x) + 0.5) / Double(width)
                let py = (Double(y) + 0.5) / Double(height)
                let w0 = ((b.y - c.y) * (px - c.x) + (c.x - b.x) * (py - c.y)) / den
                let w1 = ((c.y - a.y) * (px - c.x) + (a.x - c.x) * (py - c.y)) / den
                let w2 = 1 - w0 - w1
                guard w0 >= -0.001, w1 >= -0.001, w2 >= -0.001 else { continue }
                guard let sample = bilinear(
                    w0 * ua.x + w1 * ub.x + w2 * uc.x,
                    w0 * ua.y + w1 * ub.y + w2 * uc.y,
                    source: source
                ), sample.3 > 8 else { continue }
                let index = (y * width + x) * 4
                output[index] = sample.0
                output[index + 1] = sample.1
                output[index + 2] = sample.2
                output[index + 3] = sample.3
                painted = true
            }
        }
        return painted
    }

    private static func bilinear(
        _ u: Double,
        _ v: Double,
        source: (width: Int, height: Int, bytes: [UInt8])
    ) -> (UInt8, UInt8, UInt8, UInt8)? {
        guard source.width > 1, source.height > 1, u >= 0, v >= 0, u <= 1, v <= 1 else { return nil }
        let x = u * Double(source.width - 1)
        let y = v * Double(source.height - 1)
        let x0 = Int(x)
        let y0 = Int(y)
        let x1 = min(x0 + 1, source.width - 1)
        let y1 = min(y0 + 1, source.height - 1)
        let tx = x - Double(x0)
        let ty = y - Double(y0)
        func pixel(_ px: Int, _ py: Int) -> (Double, Double, Double, Double) {
            let index = (py * source.width + px) * 4
            return (
                Double(source.bytes[index]),
                Double(source.bytes[index + 1]),
                Double(source.bytes[index + 2]),
                Double(source.bytes[index + 3])
            )
        }
        let p00 = pixel(x0, y0)
        let p10 = pixel(x1, y0)
        let p01 = pixel(x0, y1)
        let p11 = pixel(x1, y1)
        func mix(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> UInt8 {
            let value = (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
            return UInt8(min(max(value, 0), 255))
        }
        return (mix(p00.0, p10.0, p01.0, p11.0), mix(p00.1, p10.1, p01.1, p11.1), mix(p00.2, p10.2, p01.2, p11.2), mix(p00.3, p10.3, p01.3, p11.3))
    }

    private static func meshFrom(
        corners: [TryOnPoint],
        drawable: [Bool],
        columns: Int,
        rows: Int,
        sourceLevels: [TryOnBodyLevel],
        avatarLevels: [TryOnBodyLevel],
        bounds: TryOnRect
    ) -> TryOnMesh {
        var vertices: [TryOnMeshVertex] = []
        var maxTravel = 0.0
        for row in 0...rows {
            for column in 0...columns {
                let photo = gridPoint(column: column, row: row, columns: columns, rows: rows, bounds: bounds)
                let destination = corners[row * (columns + 1) + column]
                maxTravel = max(maxTravel, hypot(destination.x - photo.x, destination.y - photo.y))
                vertices.append(TryOnMeshVertex(
                    x: Float(destination.x),
                    y: Float(destination.y),
                    u: Float(destination.x),
                    v: Float(destination.y),
                    constraint: .seam
                ))
            }
        }
        var indices: [UInt32] = []
        var used: [Int] = []
        let stride = columns + 1
        for row in 0..<rows {
            for column in 0..<columns where drawable[row * columns + column] {
                let start = UInt32(row * stride + column)
                let next = UInt32(stride)
                indices.append(contentsOf: [start, start + 1, start + next + 1, start, start + next + 1, start + next])
                used.append(contentsOf: [Int(start), Int(start + 1), Int(start + next), Int(start + next + 1)])
            }
        }
        let region = TryOnDeformationRegion(
            id: "landmark-squares",
            regionType: "landmark",
            vertexIndices: Array(Set(used)).sorted(),
            maxDisplacement: max(maxTravel, 0.02)
        )
        _ = sourceLevels
        _ = avatarLevels
        return TryOnMesh(vertices: vertices, indices: indices, regions: [region])
    }

    private static func aligned(_ rect: TryOnRect?, to landmarks: TryOnLandmarks) -> TryOnRect? {
        guard let rect, rect.isFinite else { return nil }
        guard let anchor = landmarks.chestCenter ?? landmarks.waistCenter ?? landmarks.leftHip ?? landmarks.neckCenter
            ?? landmarks.leftShoulderJoint ?? landmarks.leftKnee ?? landmarks.leftAnkle else { return rect }
        if rect.contains(anchor) { return rect }
        let flipped = TryOnRect(x: rect.x, y: 1 - (rect.y + rect.height), width: rect.width, height: rect.height)
        return flipped.contains(anchor) ? flipped : rect
    }

    private static func maskBounds(_ image: CGImage?) -> TryOnRect? {
        guard let image, let bytes = TryOnBitmap.rgba(from: image) else { return nil }
        var minX = bytes.width
        var minY = bytes.height
        var maxX = -1
        var maxY = -1
        for y in 0..<bytes.height {
            for x in 0..<bytes.width where bytes.bytes[(y * bytes.width + x) * 4] > 128 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX > minX, maxY > minY else { return nil }
        return TryOnRect(
            x: Double(minX) / Double(bytes.width),
            y: Double(minY) / Double(bytes.height),
            width: Double(maxX - minX + 1) / Double(bytes.width),
            height: Double(maxY - minY + 1) / Double(bytes.height)
        )
    }

    private static func span(_ points: [TryOnPoint?], pad: Double) -> TryOnRect? {
        span(points.compactMap { $0 }, pad: pad)
    }

    private static func span(_ points: [TryOnPoint], pad: Double) -> TryOnRect? {
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return nil }
        let left = min(max(minX - pad, 0), 1)
        let top = min(max(minY - pad, 0), 1)
        let right = min(max(maxX + pad, 0), 1)
        let bottom = min(max(maxY + pad, 0), 1)
        guard right - left >= 0.04, bottom - top >= 0.04 else { return nil }
        return TryOnRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    private static func allPoints(_ landmarks: TryOnLandmarks) -> [TryOnPoint] {
        [
            landmarks.neckCenter, landmarks.leftShoulderJoint, landmarks.rightShoulderJoint,
            landmarks.leftElbow, landmarks.rightElbow, landmarks.leftWrist, landmarks.rightWrist,
            landmarks.chestCenter, landmarks.waistCenter, landmarks.leftWaist, landmarks.rightWaist,
            landmarks.leftHip, landmarks.rightHip, landmarks.leftKnee, landmarks.rightKnee,
            landmarks.leftAnkle, landmarks.rightAnkle
        ].compactMap { $0 }
    }

    private static func levelLabel(_ name: String) -> String {
        switch name {
        case "shoulder": return "shoulders"
        case "elbow": return "elbows"
        case "wrist": return "wrists"
        case "hip": return "hips"
        case "knee": return "knees"
        case "foot": return "feet"
        default: return name
        }
    }

    private static func englishList(_ words: [String]) -> String {
        let unique = Array(NSOrderedSet(array: words)) as? [String] ?? words
        switch unique.count {
        case 0: return "body"
        case 1: return unique[0]
        case 2: return "\(unique[0]) and \(unique[1])"
        default:
            return unique.dropLast().joined(separator: ", ") + ", and " + unique[unique.count - 1]
        }
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private static func midpoint(_ left: TryOnPoint?, _ right: TryOnPoint?) -> TryOnPoint? {
        guard let left, let right else { return nil }
        return TryOnPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
    }
}
