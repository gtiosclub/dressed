import UIKit

/// Where a garment sat on the person in the upload photo.
/// Coordinates are normalized to that photo, with the origin at the top left.
struct TryOnSourceFit: Codable, Equatable {
    var landmarks: TryOnLandmarks
    var garmentBounds: TryOnRect
    /// Body point the torso hem lines up with: waist, hips, knees, or feet.
    /// Sleeve cuffs are not a hem. Tops never use the wrist or elbow here.
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
        TryOnSourceFit.hemPhrase(hemLandmark)
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
        let reading = hemReading(
            category: category,
            photo: photo,
            bounds: bounds,
            landmarks: landmarks,
            fillsBounds: false
        )
        let squares = buildSquares(
            bounds: bounds,
            columns: grid.columns,
            rows: grid.rows,
            levels: levels,
            reading: reading
        )
        guard squares.contains(where: { $0.landmark != "empty" }) else {
            return .failed("The garment area does not cover the detected body (\(detected.joined(separator: ", "))), so the piece could not be placed.")
        }
        let shoulder = topAnchor(reading: reading, landmarks: landmarks, levels: levels)
        return .fit(TryOnSourceFit(
            landmarks: landmarks,
            garmentBounds: bounds,
            hemLandmark: reading.hemName,
            hemPoint: reading.hemPoint,
            shoulderPoint: shoulder,
            cutoutFillsBounds: cutoutFillsBounds,
            gridColumns: grid.columns,
            gridRows: grid.rows,
            squares: squares
        ))
    }

    /// Name used in "Hem placed at the knees from the worn photo."
    /// Tops report the torso center, never the sleeve cuff.
    static func placementHemDescription(
        fit: TryOnSourceFit,
        category: ClothingCategory,
        photo: CGImage
    ) -> String {
        let reading = hemReading(
            category: category,
            photo: photo,
            bounds: fit.garmentBounds,
            landmarks: fit.landmarks,
            fillsBounds: fit.cutoutFillsBounds
        )
        return hemPhrase(reading.hemName)
    }

    /// Draws the cutout by mapping each square onto the same body landmarks on the avatar.
    /// Does not regenerate the garment artwork.
    /// A top's vertical scale runs from the shoulder and neck to the torso hem. Sleeve cuffs use the arm.
    static func place(
        cutout: UIImage,
        fit: TryOnSourceFit,
        avatar: TryOnLandmarks,
        canvas: TryOnCanvas,
        category: ClothingCategory
    ) -> TryOnPlacement? {
        guard let sourceImage = TryOnSourceFitStore.upright(cutout),
              let source = TryOnBitmap.rgba(from: sourceImage) else { return nil }
        let sourceLevels = bodyLevels(in: fit.landmarks)
        let avatarLevels = bodyLevels(in: avatar)
        guard sharedLevels(sourceLevels, avatarLevels).source.count >= 2 else { return nil }
        let columns = max(fit.gridColumns, gridSize(for: fit.garmentBounds).columns)
        let rows = max(fit.gridRows, gridSize(for: fit.garmentBounds).rows)
        let reading = hemReading(
            category: category,
            photo: sourceImage,
            bounds: fit.garmentBounds,
            landmarks: fit.landmarks,
            fillsBounds: fit.cutoutFillsBounds
        )
        let squares = buildSquares(
            bounds: fit.garmentBounds,
            columns: columns,
            rows: rows,
            levels: sourceLevels,
            reading: reading
        )
        var output = [UInt8](repeating: 0, count: canvas.width * canvas.height * 4)
        var drawable = Array(repeating: false, count: columns * rows)
        var corners = Array(repeating: TryOnPoint.zero, count: (columns + 1) * (rows + 1))
        for row in 0...rows {
            for column in 0...columns {
                let photoPoint = gridPoint(column: column, row: row, columns: columns, rows: rows, bounds: fit.garmentBounds)
                corners[row * (columns + 1) + column] = placed(
                    photoPoint,
                    reading: reading,
                    sourceLevels: sourceLevels,
                    avatarLevels: avatarLevels,
                    source: fit.landmarks,
                    avatar: avatar
                ).clampedToCanvas()
            }
        }
        let drew = paintLandmarkMapped(
            source: source,
            fit: fit,
            reading: reading,
            sourceLevels: sourceLevels,
            avatarLevels: avatarLevels,
            wornLandmarks: fit.landmarks,
            avatar: avatar,
            canvas: canvas,
            into: &output
        )
        for square in squares where square.column < columns && square.row < rows {
            let index = square.row * columns + square.column
            if reading.axis == .top {
                drawable[index] = drew
            } else {
                drawable[index] = square.landmark != "empty"
            }
        }
        guard drew, let image = TryOnBitmap.cgImage(width: canvas.width, height: canvas.height, bytes: output) else {
            return nil
        }
        let mesh = meshFrom(
            corners: corners,
            drawable: drawable,
            columns: columns,
            rows: rows,
            sourceLevels: sourceLevels,
            avatarLevels: avatarLevels,
            bounds: fit.garmentBounds
        )
        guard !mesh.indices.isEmpty else { return nil }
        return TryOnPlacement(image: image, mesh: mesh)
    }

    /// Expands horizontal scale so opaque fabric spans at least the avatar shoulder joint distance.
    static func widenToShoulderSpan(
        image: CGImage,
        avatar: TryOnLandmarks,
        canvas: TryOnCanvas = .canonical
    ) -> CGImage {
        guard let stats = TryOnBitmap.stats(of: image), stats.bounds.width > 1 else { return image }
        let left = avatar.leftShoulderJoint?.x ?? avatar.leftShoulderEdge?.x
        let right = avatar.rightShoulderJoint?.x ?? avatar.rightShoulderEdge?.x
        guard let left, let right else { return image }
        let targetPixels = CGFloat(max(abs(right - left), 0.08)) * CGFloat(canvas.width)
        let currentPixels = stats.bounds.width
        guard currentPixels < targetPixels * 0.97 else { return image }
        let raw = targetPixels / currentPixels
        let scale = min(max(raw, 1), 2.5)
        return TryOnBitmap.scaledX(image, scale: scale, anchorX: stats.bounds.midX, canvas: canvas) ?? image
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
            // Arms widen the shirt. The bottom stays on the torso, including a long hem, not the cuff.
            return framedBounds(
                vertical: [
                    landmarks.neckCenter, landmarks.leftShoulderJoint, landmarks.rightShoulderJoint,
                    landmarks.waistCenter, landmarks.leftHip, landmarks.rightHip,
                    landmarks.leftKnee, landmarks.rightKnee
                ],
                horizontal: [
                    landmarks.leftShoulderJoint, landmarks.rightShoulderJoint,
                    landmarks.leftElbow, landmarks.rightElbow, landmarks.leftWrist, landmarks.rightWrist,
                    landmarks.leftHip, landmarks.rightHip
                ],
                pad: 0.04
            )
        case .dresses:
            return framedBounds(
                vertical: [
                    landmarks.neckCenter, landmarks.leftShoulderJoint, landmarks.rightShoulderJoint,
                    landmarks.waistCenter, landmarks.leftHip, landmarks.rightHip,
                    landmarks.leftKnee, landmarks.rightKnee, landmarks.leftAnkle, landmarks.rightAnkle
                ],
                horizontal: [
                    landmarks.leftShoulderJoint, landmarks.rightShoulderJoint,
                    landmarks.leftElbow, landmarks.rightElbow, landmarks.leftWrist, landmarks.rightWrist,
                    landmarks.leftHip, landmarks.rightHip
                ],
                pad: 0.04
            )
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

    private enum TryOnAxis {
        case top
        case bottom
    }

    /// Measurements that keep a shirt's length on the torso. `hemY` is the body panel, not the cuff.
    private struct TryOnHemReading {
        var axis: TryOnAxis
        var centerX: Double
        var topY: Double
        var neckLineY: Double
        var shoulderLineY: Double
        var hemY: Double
        var hemName: String
        var hemPoint: TryOnPoint
        var topLevel: String
        var hemLevel: String
        var leftCuffY: Double
        var rightCuffY: Double
        var shoulderLeftX: Double
        var shoulderRightX: Double
        var hemLeftX: Double
        var hemRightX: Double
        var garmentLeftX: Double
        var garmentRightX: Double
    }

    private struct TryOnImageFrame {
        var bounds: TryOnRect
        var fillsBounds: Bool

        func imageX(_ photoX: Double) -> Double {
            guard fillsBounds else { return min(max(photoX, 0), 1) }
            return min(max((photoX - bounds.x) / max(bounds.width, 0.0001), 0), 1)
        }

        func imageY(_ photoY: Double) -> Double {
            guard fillsBounds else { return min(max(photoY, 0), 1) }
            return min(max((photoY - bounds.y) / max(bounds.height, 0.0001), 0), 1)
        }

        func photoX(_ imageX: Double) -> Double {
            guard fillsBounds else { return imageX }
            return bounds.x + imageX * bounds.width
        }

        func photoY(_ imageY: Double) -> Double {
            guard fillsBounds else { return imageY }
            return bounds.y + imageY * bounds.height
        }
    }

    private struct TryOnPixels {
        var width: Int
        var height: Int
        var bytes: [UInt8]

        func opaque(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, y >= 0, x < width, y < height else { return false }
            return bytes[(y * width + x) * 4 + 3] > 16
        }

        func pixelX(_ normalized: Double) -> Int {
            let limit = max(width - 1, 0)
            return min(max(Int((normalized * Double(limit)).rounded()), 0), limit)
        }

        func pixelY(_ normalized: Double) -> Int {
            let limit = max(height - 1, 0)
            return min(max(Int((normalized * Double(limit)).rounded()), 0), limit)
        }

        var separatesFabric: Bool {
            guard width > 1, height > 1 else { return false }
            var clear = 0
            var samples = 0
            let stepX = max(width / 24, 1)
            let stepY = max(height / 24, 1)
            var y = 0
            while y < height {
                var x = 0
                while x < width {
                    samples += 1
                    if !opaque(x, y) { clear += 1 }
                    x += stepX
                }
                y += stepY
            }
            return samples > 0 && Double(clear) / Double(samples) > 0.08
        }
    }

    fileprivate static func hemPhrase(_ name: String) -> String {
        switch name {
        case "waistCenter", "waist": return "waist"
        case "leftHip", "hip": return "hips"
        case "leftKnee", "knee": return "knees"
        case "leftAnkle", "foot": return "feet"
        default: return "hips"
        }
    }

    private static func axis(
        for category: ClothingCategory,
        bounds: TryOnRect,
        landmarks: TryOnLandmarks
    ) -> TryOnAxis {
        switch category {
        case .pants, .skirts, .shoes:
            return .bottom
        case .tops, .outerwear, .dresses, .accessories:
            return .top
        case .other:
            let shoulderY = bodyPoint("shoulder", in: landmarks)?.y ?? landmarks.neckCenter?.y
            if let shoulderY, bounds.y <= shoulderY + 0.06 { return .top }
            return .bottom
        }
    }

    private static func hemReading(
        category: ClothingCategory,
        photo: CGImage,
        bounds: TryOnRect,
        landmarks: TryOnLandmarks,
        fillsBounds: Bool
    ) -> TryOnHemReading {
        let axis = axis(for: category, bounds: bounds, landmarks: landmarks)
        let frame = TryOnImageFrame(bounds: bounds, fillsBounds: fillsBounds)
        let pixels = TryOnBitmap.rgba(from: photo).map {
            TryOnPixels(width: $0.width, height: $0.height, bytes: $0.bytes)
        }
        let fabric = pixels?.separatesFabric == true ? pixels : nil
        let centerX = torsoCenterX(landmarks: landmarks, bounds: bounds)
        let shoulders = shoulderEdges(landmarks: landmarks, centerX: centerX, bounds: bounds)
        let bottom = bounds.y + bounds.height
        let shoulderLineY = measuredShoulderLine(
            fabric: fabric,
            frame: frame,
            shoulders: shoulders,
            bounds: bounds,
            landmarks: landmarks
        )
        let neckLineY = measuredNeckLine(
            fabric: fabric,
            frame: frame,
            centerX: centerX,
            bounds: bounds,
            shoulderLineY: shoulderLineY,
            landmarks: landmarks
        )
        let hemSpan = measuredTorsoHem(
            fabric: fabric,
            frame: frame,
            centerX: centerX,
            shoulderLineY: shoulderLineY,
            bounds: bounds
        )
        let hemY = min(max(hemSpan?.y ?? bottom, shoulderLineY + 0.05), bottom)
        let hemEdges = hemEdges(
            span: hemSpan,
            centerX: centerX,
            shoulders: shoulders,
            landmarks: landmarks
        )
        let leftCuffY = measuredCuff(
            fabric: fabric,
            frame: frame,
            side: .left,
            bodyLeft: hemEdges.left,
            bodyRight: hemEdges.right,
            shoulderLineY: shoulderLineY,
            bounds: bounds,
            landmarks: landmarks
        )
        let rightCuffY = measuredCuff(
            fabric: fabric,
            frame: frame,
            side: .right,
            bodyLeft: hemEdges.left,
            bodyRight: hemEdges.right,
            shoulderLineY: shoulderLineY,
            bounds: bounds,
            landmarks: landmarks
        )
        let anchors = hemAnchors(
            category: category,
            axis: axis,
            topY: bounds.y,
            hemY: hemY,
            landmarks: landmarks
        )
        return TryOnHemReading(
            axis: axis,
            centerX: centerX,
            topY: bounds.y,
            neckLineY: neckLineY,
            shoulderLineY: shoulderLineY,
            hemY: hemY,
            hemName: anchors.hemName,
            hemPoint: anchors.hemPoint,
            topLevel: anchors.topLevel,
            hemLevel: anchors.hemLevel,
            leftCuffY: leftCuffY,
            rightCuffY: rightCuffY,
            shoulderLeftX: shoulders.left,
            shoulderRightX: shoulders.right,
            hemLeftX: hemEdges.left,
            hemRightX: hemEdges.right,
            garmentLeftX: bounds.x,
            garmentRightX: bounds.x + bounds.width
        )
    }

    private static func topAnchor(
        reading: TryOnHemReading,
        landmarks: TryOnLandmarks,
        levels: [TryOnBodyLevel]
    ) -> TryOnPoint {
        if reading.axis == .bottom {
            return landmarks.waistCenter
                ?? bodyPoint("hip", in: landmarks)
                ?? levels.first?.center
                ?? TryOnPoint(x: reading.centerX, y: reading.topY)
        }
        return bodyPoint("shoulder", in: landmarks)
            ?? landmarks.neckCenter
            ?? levels.first?.center
            ?? TryOnPoint(x: reading.centerX, y: reading.shoulderLineY)
    }

    private static func placed(
        _ point: TryOnPoint,
        reading: TryOnHemReading,
        sourceLevels: [TryOnBodyLevel],
        avatarLevels: [TryOnBodyLevel],
        source: TryOnLandmarks,
        avatar: TryOnLandmarks
    ) -> TryOnPoint {
        if reading.axis == .bottom {
            return placedBottom(point, reading: reading, sourceLevels: sourceLevels, avatarLevels: avatarLevels)
        }
        if isSleeve(point, reading: reading),
           let sleeve = placedSleeve(point, reading: reading, source: source, avatar: avatar) {
            return sleeve
        }
        return placedTop(point, reading: reading, avatar: avatar)
    }

    /// One scale from the shoulder or neckline to the torso hem. Wrist level is not on this scale.
    private static func placedTop(
        _ point: TryOnPoint,
        reading: TryOnHemReading,
        avatar: TryOnLandmarks
    ) -> TryOnPoint {
        guard let avatarShoulderY = bodyPoint("shoulder", in: avatar)?.y ?? avatar.neckCenter?.y else {
            return point
        }
        let avatarNeckY = avatar.neckCenter?.y ?? avatarShoulderY
        let avatarHem = resolvedTorsoPoint(reading.hemName, landmarks: avatar)?.point ?? reading.hemPoint
        let collarAbove = reading.neckLineY + 0.008 < reading.shoulderLineY
        let column = columnEdges(reading, y: point.y)
        let half = max((column.right - column.left) / 2, 0.04)
        let blend = min(max(abs(point.x - reading.centerX) / half, 0), 1)
        let sourceTop = collarAbove ? lerp(reading.neckLineY, reading.shoulderLineY, blend) : reading.shoulderLineY
        let avatarTop = collarAbove ? lerp(avatarNeckY, avatarShoulderY, blend) : avatarShoulderY
        let sourceHem = max(reading.hemY, sourceTop + 0.05)
        let t = min(max((point.y - sourceTop) / (sourceHem - sourceTop), 0), 1)
        let avatarY = lerp(avatarTop, avatarHem.y, t)
        let s = (point.x - column.left) / max(column.right - column.left, 0.04)
        let avatarColumn = avatarColumnEdges(at: t, avatar: avatar, hemLevel: reading.hemLevel)
        return TryOnPoint(
            x: avatarColumn.left + s * (avatarColumn.right - avatarColumn.left),
            y: avatarY
        )
    }

    private enum TryOnSide {
        case left
        case right
    }

    private static func placedSleeve(
        _ point: TryOnPoint,
        reading: TryOnHemReading,
        source: TryOnLandmarks,
        avatar: TryOnLandmarks
    ) -> TryOnPoint? {
        let onLeft = point.x < reading.centerX
        let sourceShoulder = TryOnPoint(
            x: onLeft ? reading.shoulderLeftX : reading.shoulderRightX,
            y: reading.shoulderLineY
        )
        guard let avatarShoulder = (onLeft ? avatar.leftShoulderJoint : avatar.rightShoulderJoint)
            ?? bodyPoint("shoulder", in: avatar) else { return nil }
        let sourceElbow = onLeft ? source.leftElbow : source.rightElbow
        let sourceWrist = onLeft ? source.leftWrist : source.rightWrist
        let avatarElbow = onLeft ? avatar.leftElbow : avatar.rightElbow
        let avatarWrist = onLeft ? avatar.leftWrist : avatar.rightWrist
        let cuffY = onLeft ? reading.leftCuffY : reading.rightCuffY
        let useElbow: Bool = {
            switch (sourceElbow?.y, sourceWrist?.y) {
            case let (elbow?, wrist?): return abs(cuffY - elbow) <= abs(cuffY - wrist)
            case (_?, nil): return true
            default: return false
            }
        }()
        let sourceEnd = useElbow ? (sourceElbow ?? sourceWrist) : (sourceWrist ?? sourceElbow)
        let avatarEnd = useElbow ? (avatarElbow ?? avatarWrist) : (avatarWrist ?? avatarElbow)
        guard let sourceEnd, let avatarEnd else { return nil }
        let span = max(cuffY - reading.shoulderLineY, 0.04)
        let t = min(max((point.y - reading.shoulderLineY) / span, 0), 1)
        let sourceElbowT: Double = {
            guard !useElbow, let elbowY = sourceElbow?.y else { return 1 }
            return min(max((elbowY - reading.shoulderLineY) / span, 0.15), 0.85)
        }()
        let sourceJoint: TryOnPoint
        let avatarJoint: TryOnPoint
        if !useElbow, let sourceElbow, let avatarElbow, t <= sourceElbowT {
            let u = sourceElbowT > 0.001 ? t / sourceElbowT : 0
            sourceJoint = lerpPoint(sourceShoulder, sourceElbow, u)
            avatarJoint = lerpPoint(avatarShoulder, avatarElbow, u)
        } else if !useElbow, let sourceElbow, let avatarElbow {
            let u = (t - sourceElbowT) / max(1 - sourceElbowT, 0.001)
            sourceJoint = lerpPoint(sourceElbow, sourceEnd, u)
            avatarJoint = lerpPoint(avatarElbow, avatarEnd, u)
        } else {
            sourceJoint = lerpPoint(sourceShoulder, sourceEnd, t)
            avatarJoint = lerpPoint(avatarShoulder, avatarEnd, t)
        }
        let sourceWidth = max(abs(reading.shoulderRightX - reading.shoulderLeftX), 0.08)
        let avatarLeft = avatar.leftShoulderJoint?.x ?? avatarShoulder.x
        let avatarRight = avatar.rightShoulderJoint?.x ?? avatarShoulder.x
        let avatarWidth = max(abs(avatarRight - avatarLeft), 0.08)
        return TryOnPoint(
            x: avatarJoint.x + (point.x - sourceJoint.x) * (avatarWidth / sourceWidth),
            y: avatarJoint.y
        )
    }

    private static func placedBottom(
        _ point: TryOnPoint,
        reading: TryOnHemReading,
        sourceLevels: [TryOnBodyLevel],
        avatarLevels: [TryOnBodyLevel]
    ) -> TryOnPoint {
        if reading.topLevel == reading.hemLevel {
            let names: Set<String> = ["knee", "foot"]
            let shared = sharedLevels(
                sourceLevels.filter { names.contains($0.name) },
                avatarLevels.filter { names.contains($0.name) }
            )
            guard shared.source.count >= 2 else { return point }
            return map(point, from: shared.source, to: shared.avatar)
        }
        let names = levelSpan(from: reading.topLevel, through: reading.hemLevel)
        var source = sourceLevels.filter { names.contains($0.name) }
        let avatar = avatarLevels.filter { names.contains($0.name) }
        source = rescale(source, top: reading.topLevel, topY: reading.topY, hem: reading.hemLevel, hemY: reading.hemY)
        let shared = sharedLevels(source, avatar)
        guard shared.source.count >= 2 else { return point }
        return map(point, from: shared.source, to: shared.avatar)
    }

    private static func isSleeve(_ point: TryOnPoint, reading: TryOnHemReading) -> Bool {
        guard reading.axis == .top else { return false }
        let edges = columnEdges(reading, y: point.y)
        return point.x < edges.left - 0.012 || point.x > edges.right + 0.012
    }

    private static func columnEdges(_ reading: TryOnHemReading, y: Double) -> (left: Double, right: Double) {
        let span = max(reading.hemY - reading.shoulderLineY, 0.05)
        let t = min(max((y - reading.shoulderLineY) / span, 0), 1)
        let left = lerp(reading.shoulderLeftX, reading.hemLeftX, t)
        let right = lerp(reading.shoulderRightX, reading.hemRightX, t)
        var l = min(left, right)
        var r = max(left, right)
        let shoulderJointSpan = max(reading.shoulderRightX - reading.shoulderLeftX, 0.08)
        let garmentSpan = max(reading.garmentRightX - reading.garmentLeftX, shoulderJointSpan)
        let topBlend = min(max(1 - t * 2.5, 0), 1)
        if topBlend > 0.001 {
            let center = (l + r) / 2
            let currentHalf = (r - l) / 2
            let targetHalf = max(garmentSpan / 2 * 0.92, shoulderJointSpan / 2)
            let half = lerp(currentHalf, targetHalf, topBlend)
            l = center - half
            r = center + half
        }
        return (l, r)
    }

    private static func avatarColumnEdges(
        at t: Double,
        avatar: TryOnLandmarks,
        hemLevel: String
    ) -> (left: Double, right: Double) {
        let shoulderLeft = avatar.leftShoulderJoint?.x ?? 0.38
        let shoulderRight = avatar.rightShoulderJoint?.x ?? 0.62
        let center = bodyPoint("shoulder", in: avatar)?.x ?? (shoulderLeft + shoulderRight) / 2
        let topHalf = max(abs(shoulderRight - shoulderLeft) / 2, 0.05)
        let hemLeft: Double
        let hemRight: Double
        switch hemLevel {
        case "waist":
            hemLeft = avatar.leftWaist?.x ?? avatar.leftHip?.x ?? shoulderLeft
            hemRight = avatar.rightWaist?.x ?? avatar.rightHip?.x ?? shoulderRight
        case "knee":
            hemLeft = avatar.leftKnee?.x ?? avatar.leftHip?.x ?? shoulderLeft
            hemRight = avatar.rightKnee?.x ?? avatar.rightHip?.x ?? shoulderRight
        case "foot":
            hemLeft = avatar.leftAnkle?.x ?? avatar.leftKnee?.x ?? avatar.leftHip?.x ?? shoulderLeft
            hemRight = avatar.rightAnkle?.x ?? avatar.rightKnee?.x ?? avatar.rightHip?.x ?? shoulderRight
        default:
            hemLeft = avatar.leftHip?.x ?? avatar.leftWaist?.x ?? shoulderLeft
            hemRight = avatar.rightHip?.x ?? avatar.rightWaist?.x ?? shoulderRight
        }
        let hemHalf = max(abs(hemRight - hemLeft) / 2, topHalf * 0.65)
        let half = lerp(topHalf, hemHalf, min(max(t, 0), 1))
        return (center - half, center + half)
    }

    private static func torsoCenterX(landmarks: TryOnLandmarks, bounds: TryOnRect) -> Double {
        bodyPoint("shoulder", in: landmarks)?.x
            ?? landmarks.waistCenter?.x
            ?? bodyPoint("hip", in: landmarks)?.x
            ?? bounds.x + bounds.width / 2
    }

    private static func shoulderEdges(
        landmarks: TryOnLandmarks,
        centerX: Double,
        bounds: TryOnRect
    ) -> (left: Double, right: Double) {
        let left = landmarks.leftShoulderJoint?.x ?? landmarks.leftWaist?.x ?? centerX - bounds.width * 0.22
        let right = landmarks.rightShoulderJoint?.x ?? landmarks.rightWaist?.x ?? centerX + bounds.width * 0.22
        return (min(left, right), max(left, right))
    }

    private static func measuredShoulderLine(
        fabric: TryOnPixels?,
        frame: TryOnImageFrame,
        shoulders: (left: Double, right: Double),
        bounds: TryOnRect,
        landmarks: TryOnLandmarks
    ) -> Double {
        let fallback = min(
            max(bodyPoint("shoulder", in: landmarks)?.y ?? bounds.y, bounds.y),
            bounds.y + bounds.height * 0.35
        )
        guard let fabric else { return fallback }
        let yMin = frame.imageY(bounds.y)
        let yMax = frame.imageY(min(bounds.y + bounds.height * 0.62, bounds.y + bounds.height))
        let left = topOpaqueY(fabric, imageX: frame.imageX(shoulders.left), halfWidth: 0.03, yMin: yMin, yMax: yMax)
        let right = topOpaqueY(fabric, imageX: frame.imageX(shoulders.right), halfWidth: 0.03, yMin: yMin, yMax: yMax)
        let imageY: Double?
        switch (left, right) {
        case let (left?, right?): imageY = (left + right) / 2
        case let (left?, nil): imageY = left
        case let (nil, right?): imageY = right
        default: imageY = nil
        }
        guard let imageY else { return fallback }
        let photoY = frame.photoY(imageY)
        if photoY > bounds.y + bounds.height * 0.5 { return fallback }
        return photoY
    }

    private static func measuredNeckLine(
        fabric: TryOnPixels?,
        frame: TryOnImageFrame,
        centerX: Double,
        bounds: TryOnRect,
        shoulderLineY: Double,
        landmarks: TryOnLandmarks
    ) -> Double {
        let fallback = min(landmarks.neckCenter?.y ?? shoulderLineY, shoulderLineY)
        guard let fabric else { return fallback }
        let neck = landmarks.neckCenter?.y ?? bounds.y
        let yMin = frame.imageY(max(bounds.y, neck - 0.04))
        let yMax = frame.imageY(min(shoulderLineY + bounds.height * 0.2, bounds.y + bounds.height))
        guard let imageY = topOpaqueY(fabric, imageX: frame.imageX(centerX), halfWidth: 0.035, yMin: yMin, yMax: yMax) else {
            return fallback
        }
        return frame.photoY(imageY)
    }

    private static func measuredTorsoHem(
        fabric: TryOnPixels?,
        frame: TryOnImageFrame,
        centerX: Double,
        shoulderLineY: Double,
        bounds: TryOnRect
    ) -> (y: Double, left: Double, right: Double)? {
        guard let fabric else { return nil }
        let yMin = frame.imageY(shoulderLineY)
        let yMax = frame.imageY(bounds.y + bounds.height)
        guard let span = torsoHem(in: fabric, centerX: frame.imageX(centerX), yMin: yMin, yMax: yMax) else { return nil }
        return (frame.photoY(span.y), frame.photoX(span.left), frame.photoX(span.right))
    }

    private static func hemEdges(
        span: (y: Double, left: Double, right: Double)?,
        centerX: Double,
        shoulders: (left: Double, right: Double),
        landmarks: TryOnLandmarks
    ) -> (left: Double, right: Double) {
        let hipLeft = landmarks.leftHip?.x ?? shoulders.left
        let hipRight = landmarks.rightHip?.x ?? shoulders.right
        let fallbackHalf = max(abs(hipRight - hipLeft), abs(shoulders.right - shoulders.left), 0.12) / 2
        guard let span else { return (centerX - fallbackHalf, centerX + fallbackHalf) }
        if span.right - span.left < max(0.06, fallbackHalf) {
            return (centerX - fallbackHalf, centerX + fallbackHalf)
        }
        return (span.left, span.right)
    }

    private static func measuredCuff(
        fabric: TryOnPixels?,
        frame: TryOnImageFrame,
        side: TryOnSide,
        bodyLeft: Double,
        bodyRight: Double,
        shoulderLineY: Double,
        bounds: TryOnRect,
        landmarks: TryOnLandmarks
    ) -> Double {
        let elbow = side == .left ? landmarks.leftElbow : landmarks.rightElbow
        let wrist = side == .left ? landmarks.leftWrist : landmarks.rightWrist
        let fallback = wrist?.y ?? elbow?.y ?? (shoulderLineY + 0.2)
        guard let fabric else { return fallback }
        let imageY = lowestSideOpaque(
            fabric,
            side: side,
            bodyLeft: frame.imageX(bodyLeft),
            bodyRight: frame.imageX(bodyRight),
            yMin: frame.imageY(shoulderLineY),
            yMax: frame.imageY(bounds.y + bounds.height)
        )
        guard let imageY else { return elbow?.y ?? fallback }
        return frame.photoY(imageY)
    }

    private static func hemAnchors(
        category: ClothingCategory,
        axis: TryOnAxis,
        topY: Double,
        hemY: Double,
        landmarks: TryOnLandmarks
    ) -> (hemName: String, hemPoint: TryOnPoint, topLevel: String, hemLevel: String) {
        if category == .shoes {
            let foot = bodyPoint("foot", in: landmarks) ?? TryOnPoint(x: 0.5, y: hemY)
            return ("leftAnkle", foot, "foot", "foot")
        }
        if axis == .bottom {
            let top = closest(["waistCenter", "leftHip"], to: topY, landmarks: landmarks)
            let hem = closest(["leftKnee", "leftAnkle"], to: hemY, landmarks: landmarks)
            let hemPair = hem ?? top ?? ("leftAnkle", TryOnPoint(x: 0.5, y: hemY))
            let topPair = top ?? hemPair
            return (hemPair.0, hemPair.1, levelName(forHem: topPair.0), levelName(forHem: hemPair.0))
        }
        if let hem = closest(["waistCenter", "leftHip", "leftKnee", "leftAnkle"], to: hemY, landmarks: landmarks) {
            return (hem.0, hem.1, "shoulder", levelName(forHem: hem.0))
        }
        let point = bodyPoint("hip", in: landmarks) ?? TryOnPoint(x: 0.5, y: hemY)
        return ("leftHip", point, "shoulder", "hip")
    }

    private static func closest(
        _ names: [String],
        to y: Double,
        landmarks: TryOnLandmarks
    ) -> (String, TryOnPoint)? {
        let pairs: [(String, TryOnPoint)] = names.compactMap { name in
            guard let point = torsoCandidate(name, landmarks: landmarks) else { return nil }
            return (name, point)
        }
        return pairs.min { abs($0.1.y - y) < abs($1.1.y - y) }
    }

    private static func torsoCandidate(_ name: String, landmarks: TryOnLandmarks) -> TryOnPoint? {
        switch name {
        case "waistCenter": return landmarks.waistCenter
        case "leftHip": return bodyPoint("hip", in: landmarks)
        case "leftKnee": return bodyPoint("knee", in: landmarks)
        case "leftAnkle": return bodyPoint("foot", in: landmarks)
        default: return nil
        }
    }

    private static func resolvedTorsoPoint(_ name: String, landmarks: TryOnLandmarks) -> (name: String, point: TryOnPoint)? {
        let order = ["waistCenter", "leftHip", "leftKnee", "leftAnkle"]
        if let point = torsoCandidate(name, landmarks: landmarks) { return (name, point) }
        guard let index = order.firstIndex(of: name) else { return nil }
        var best: (String, TryOnPoint, Int)?
        for (offset, candidate) in order.enumerated() {
            guard let point = torsoCandidate(candidate, landmarks: landmarks) else { continue }
            let distance = abs(offset - index)
            if best == nil || distance < best!.2 { best = (candidate, point, distance) }
        }
        return best.map { ($0.0, $0.1) }
    }

    private static func levelName(forHem name: String) -> String {
        switch name {
        case "waistCenter", "waist": return "waist"
        case "leftHip", "hip": return "hip"
        case "leftKnee", "knee": return "knee"
        case "leftAnkle", "foot": return "foot"
        case "shoulder": return "shoulder"
        default: return "hip"
        }
    }

    private static func levelSpan(from top: String, through hem: String) -> Set<String> {
        let order = ["neck", "shoulder", "waist", "hip", "knee", "foot"]
        guard let start = order.firstIndex(of: top), let end = order.firstIndex(of: hem) else {
            return [top, hem]
        }
        if start <= end { return Set(order[start...end]) }
        return Set(order[end...start])
    }

    private static func rescale(
        _ levels: [TryOnBodyLevel],
        top: String,
        topY: Double,
        hem: String,
        hemY: Double
    ) -> [TryOnBodyLevel] {
        guard let topLevel = levels.first(where: { $0.name == top }),
              let hemLevel = levels.first(where: { $0.name == hem }) else { return levels }
        let span = hemLevel.center.y - topLevel.center.y
        guard span > 0.02 else { return levels }
        return levels.map { level in
            var level = level
            let t = (level.center.y - topLevel.center.y) / span
            let y = topY + t * (hemY - topY)
            let delta = y - level.center.y
            level.center.y = y
            level.left.y += delta
            level.right.y += delta
            return level
        }.sorted { $0.center.y < $1.center.y }
    }

    private static func topOpaqueY(
        _ pixels: TryOnPixels,
        imageX: Double,
        halfWidth: Double,
        yMin: Double,
        yMax: Double
    ) -> Double? {
        let x0 = pixels.pixelX(imageX - halfWidth)
        let x1 = pixels.pixelX(imageX + halfWidth)
        let start = pixels.pixelY(min(yMin, yMax))
        let end = pixels.pixelY(max(yMin, yMax))
        let needed = max(1, (x1 - x0) / 4)
        let step = max(1, pixels.height / 500)
        var y = start
        while y <= end {
            var hits = 0
            var x = x0
            while x <= x1 {
                if pixels.opaque(x, y) { hits += 1 }
                x += 1
            }
            if hits >= needed {
                return Double(y) / Double(max(pixels.height - 1, 1))
            }
            y += step
        }
        return nil
    }

    /// Lowest opaque row in the center band. Rows where only the cuffs remain are skipped.
    private static func torsoHem(
        in pixels: TryOnPixels,
        centerX: Double,
        yMin: Double,
        yMax: Double
    ) -> (y: Double, left: Double, right: Double)? {
        let center = pixels.pixelX(centerX)
        let start = pixels.pixelY(min(yMin, yMax))
        let end = pixels.pixelY(max(yMin, yMax))
        guard end > start else { return nil }
        let band = max(2, pixels.width / 48)
        let step = max(1, pixels.height / 500)
        var y = end
        while y >= start {
            var hits = 0
            let x0 = max(0, center - band)
            let x1 = min(pixels.width - 1, center + band)
            var x = x0
            while x <= x1 {
                if pixels.opaque(x, y) { hits += 1 }
                x += 1
            }
            if hits >= max(2, (x1 - x0) / 3) {
                var left = center
                var right = center
                while left > 0 && pixels.opaque(left - 1, y) { left -= 1 }
                while right < pixels.width - 1 && pixels.opaque(right + 1, y) { right += 1 }
                let span = Double(right - left) / Double(max(pixels.width - 1, 1))
                if span > 0.04 {
                    let limit = Double(max(pixels.width - 1, 1))
                    return (
                        Double(y) / Double(max(pixels.height - 1, 1)),
                        Double(left) / limit,
                        Double(right) / limit
                    )
                }
            }
            y -= step
        }
        return nil
    }

    private static func lowestSideOpaque(
        _ pixels: TryOnPixels,
        side: TryOnSide,
        bodyLeft: Double,
        bodyRight: Double,
        yMin: Double,
        yMax: Double
    ) -> Double? {
        let startX = side == .left ? 0 : pixels.pixelX(bodyRight)
        let endX = side == .left ? pixels.pixelX(bodyLeft) : pixels.width - 1
        guard endX > startX + 1 else { return nil }
        let start = pixels.pixelY(min(yMin, yMax))
        let end = pixels.pixelY(max(yMin, yMax))
        let step = max(1, pixels.height / 400)
        var y = end
        while y >= start {
            var x = startX
            while x <= endX {
                if pixels.opaque(x, y) {
                    return Double(y) / Double(max(pixels.height - 1, 1))
                }
                x += max(1, (endX - startX) / 24)
            }
            y -= step
        }
        return nil
    }

    private static func lerpPoint(_ a: TryOnPoint, _ b: TryOnPoint, _ t: Double) -> TryOnPoint {
        TryOnPoint(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t))
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
        levels: [TryOnBodyLevel],
        reading: TryOnHemReading
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
                    landmark: classify(rect, levels: levels, reading: reading),
                    source: rect
                ))
            }
        }
        return squares
    }

    private static func classify(
        _ rect: TryOnRect,
        levels: [TryOnBodyLevel],
        reading: TryOnHemReading
    ) -> String {
        let center = rect.center
        let order = ["neck", "shoulder", "waist", "hip", "knee", "foot"]
        let names: [String]
        if reading.axis == .bottom {
            names = reading.topLevel == "foot"
                ? ["knee", "foot"]
                : order.filter { levelSpan(from: reading.topLevel, through: reading.hemLevel).contains($0) }
        } else if isSleeve(center, reading: reading) {
            names = ["shoulder", "elbow", "wrist"]
        } else if let end = order.firstIndex(of: reading.hemLevel) {
            names = Array(order[...end])
        } else {
            names = ["neck", "shoulder", "waist", "hip", "knee", "foot"]
        }
        let filtered = levels.filter { names.contains($0.name) }
        if filtered.isEmpty { return reading.axis == .top ? "shoulder" : "empty" }
        if reading.axis == .bottom, outsideBody(center, levels: filtered) { return "empty" }
        let probes: [(String, TryOnPoint)] = filtered.flatMap { level in
            [(level.name, level.center), (level.name, level.left), (level.name, level.right)]
        }
        var best: (String, Double)?
        for probe in probes where rect.contains(probe.1) {
            let distance = hypot(probe.1.x - center.x, probe.1.y - center.y)
            if best == nil || distance < best!.1 { best = (probe.0, distance) }
        }
        if let best { return best.0 }
        guard filtered.count >= 2 else { return filtered[0].name }
        let (upper, lower, t) = bracket(center.y, filtered)
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

    /// Maps a cutout image sample to the worn-photo point `placed()` expects.
    private static func photoPointFromCutout(imageU: Double, imageV: Double, fit: TryOnSourceFit) -> TryOnPoint {
        if fit.cutoutFillsBounds {
            let bounds = fit.garmentBounds
            return TryOnPoint(
                x: bounds.x + min(max(imageU, 0), 1) * bounds.width,
                y: bounds.y + min(max(imageV, 0), 1) * bounds.height
            )
        }
        return TryOnPoint(x: min(max(imageU, 0), 1), y: min(max(imageV, 0), 1))
    }

    /// One coherent warp: each opaque cutout pixel maps through `placed()`; sleeves stay on arms.
    @discardableResult
    private static func paintLandmarkMapped(
        source: (width: Int, height: Int, bytes: [UInt8]),
        fit: TryOnSourceFit,
        reading: TryOnHemReading,
        sourceLevels: [TryOnBodyLevel],
        avatarLevels: [TryOnBodyLevel],
        wornLandmarks: TryOnLandmarks,
        avatar: TryOnLandmarks,
        canvas: TryOnCanvas,
        into output: inout [UInt8]
    ) -> Bool {
        guard source.width > 0, source.height > 0 else { return false }
        let widthLimit = max(source.width - 1, 1)
        let heightLimit = max(source.height - 1, 1)
        let step = max(1, min(source.width, source.height) / 640)
        var drew = false
        var y = 0
        while y < source.height {
            var x = 0
            while x < source.width {
                let index = (y * source.width + x) * 4 + 3
                let alpha = source.bytes[index]
                if alpha > 8 {
                    let imageU = Double(x) / Double(widthLimit)
                    let imageV = Double(y) / Double(heightLimit)
                    let photo = photoPointFromCutout(imageU: imageU, imageV: imageV, fit: fit)
                    let dest = placed(
                        photo,
                        reading: reading,
                        sourceLevels: sourceLevels,
                        avatarLevels: avatarLevels,
                        source: wornLandmarks,
                        avatar: avatar
                    ).clampedToCanvas()
                    if splatColor(
                        (
                            source.bytes[index - 3],
                            source.bytes[index - 2],
                            source.bytes[index - 1],
                            alpha
                        ),
                        at: dest,
                        into: &output,
                        canvas: canvas
                    ) {
                        drew = true
                    }
                }
                x += step
            }
            y += step
        }
        return drew
    }

    private static func splatColor(
        _ color: (UInt8, UInt8, UInt8, UInt8),
        at point: TryOnPoint,
        into output: inout [UInt8],
        canvas: TryOnCanvas
    ) -> Bool {
        let fx = point.x * Double(canvas.width) - 0.5
        let fy = point.y * Double(canvas.height) - 0.5
        let x0 = Int(floor(fx))
        let y0 = Int(floor(fy))
        let tx = fx - Double(x0)
        let ty = fy - Double(y0)
        var wrote = false
        for row in 0...1 {
            for column in 0...1 {
                let px = x0 + column
                let py = y0 + row
                guard px >= 0, py >= 0, px < canvas.width, py < canvas.height else { continue }
                let weight = (column == 0 ? (1 - tx) : tx) * (row == 0 ? (1 - ty) : ty)
                guard weight > 0.02 else { continue }
                let offset = (py * canvas.width + px) * 4
                let blended = UInt8(min(255, Int(Double(color.3) * weight) + (weight < 0.99 ? Int(Double(output[offset + 3]) * (1 - weight)) : 0)))
                guard blended > 8 else { continue }
                output[offset] = color.0
                output[offset + 1] = color.1
                output[offset + 2] = color.2
                output[offset + 3] = max(output[offset + 3], blended)
                wrote = true
            }
        }
        return wrote
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

    private static func framedBounds(
        vertical: [TryOnPoint?],
        horizontal: [TryOnPoint?],
        pad: Double
    ) -> TryOnRect? {
        let verticalPoints = vertical.compactMap { $0 }
        let sidePoints = horizontal.compactMap { $0 } + verticalPoints
        guard let top = verticalPoints.map(\.y).min(),
              let bottom = verticalPoints.map(\.y).max(),
              let left = sidePoints.map(\.x).min(),
              let right = sidePoints.map(\.x).max() else { return nil }
        let minX = min(max(left - pad, 0), 1)
        let minY = min(max(top - pad, 0), 1)
        let maxX = min(max(right + pad, 0), 1)
        let maxY = min(max(bottom + pad, 0), 1)
        guard maxX - minX >= 0.04, maxY - minY >= 0.04 else { return nil }
        return TryOnRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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
