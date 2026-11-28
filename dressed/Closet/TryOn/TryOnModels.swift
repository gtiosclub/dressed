import Foundation

/// Logical portrait canvas shared by the canonical avatar and every fitted garment.
/// Normalized coordinates use a top-left origin.
struct TryOnCanvas: Codable, Equatable, Hashable {
    var width: Int
    var height: Int

    static let canonical = TryOnCanvas(width: 1024, height: 1536)
    static let coordinateSystem = "normalized_top_left"

    var size: (width: Double, height: Double) {
        (Double(width), Double(height))
    }
}

struct TryOnPoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double

    static let zero = TryOnPoint(x: 0, y: 0)

    var isFinite: Bool { x.isFinite && y.isFinite }

    func clampedToCanvas() -> TryOnPoint {
        TryOnPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }
}

struct TryOnRect: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var center: TryOnPoint {
        TryOnPoint(x: x + width / 2, y: y + height / 2)
    }

    var isFinite: Bool {
        x.isFinite && y.isFinite && width.isFinite && height.isFinite && width > 0 && height > 0
    }

    func contains(_ point: TryOnPoint) -> Bool {
        point.x >= x && point.x <= x + width && point.y >= y && point.y <= y + height
    }
}

enum TryOnJobStatus: String, Codable, Equatable {
    case queued
    case preparing
    case fitting
    case segmenting
    case validating
    case ready
    case retrying
    case needsReview = "needs_review"
    case failed
}

enum TryOnVersions {
    static let style = "closet-tryon-1"
    static let prompt = "prompt-v4"
    static let bodyPartPrompt = "body-part-prompt-v2"
    static let bodyPartGeneration = "body-part-v2"
    static let poseSet = "poses-v1"
    static let provider = "gpt-image-2.5-sunburst"
    static let processing = 8
    /// Outfit composite baked from per-item body-part layers instead of overlay fitting.
    static let bodyPartProcessing = 14
    /// Single OpenAI image for the full worn outfit aligned to the avatar (preferred display path).
    static let alignedOutfitProcessing = 16
    /// When false, body-part PNGs are references only — not stacked or skin-slot baked for display.
    static let bodyPartTileCompositingEnabled = false
    static let maxLocalDisplacement = 0.02
}

/// Non-overlapping body regions for layered avatar try-on. Changing one slot must preserve the others.
enum TryOnBodySlot: String, Codable, CaseIterable {
    case top
    case bottom
    case shoes
    case headwear

    static func slot(for category: ClothingCategory, name: String? = nil) -> TryOnBodySlot? {
        switch category {
        case .tops, .outerwear: return .top
        case .pants, .skirts, .dresses: return .bottom
        case .shoes: return .shoes
        case .accessories:
            if let name, scarfLikeName(name) { return .top }
            return .headwear
        case .other: return nil
        }
    }

    static func slot(for item: ClothingItem) -> TryOnBodySlot? {
        slot(for: item.category, name: item.name)
    }

    static func scarfLikeName(_ name: String) -> Bool {
        let words = name.lowercased().split { !$0.isLetter }
        return words.contains("scarf") || words.contains("shawl")
    }

    var displayName: String {
        switch self {
        case .top: return "top"
        case .bottom: return "bottom"
        case .shoes: return "shoes"
        case .headwear: return "headwear"
        }
    }

    /// Normalized canvas frame for compositing a body-part PNG onto the canonical figure.
    func figureFrame(landmarks: TryOnLandmarks) -> TryOnRect {
        let shoulderLeft = landmarks.leftShoulderJoint?.x ?? landmarks.leftShoulderEdge?.x ?? 0.22
        let shoulderRight = landmarks.rightShoulderJoint?.x ?? landmarks.rightShoulderEdge?.x ?? 0.78
        let left = min(shoulderLeft, shoulderRight)
        let right = max(shoulderLeft, shoulderRight)
        let shoulderSpan = max(abs(right - left), 0.22)
        let midX = (left + right) / 2
        let horizontalPad = shoulderSpan * 0.16
        switch self {
        case .top:
            let topY = min(
                landmarks.neckCenter?.y ?? 0.14,
                landmarks.leftShoulderJoint?.y ?? landmarks.rightShoulderJoint?.y ?? 0.16
            ) - 0.02
            let bottomY = max(
                landmarks.waistCenter?.y ?? 0.48,
                landmarks.leftHip?.y ?? landmarks.rightHip?.y ?? 0.50
            )
            let height = max(bottomY - topY, 0.24)
            let width = min(max(shoulderSpan + horizontalPad * 2, 0.46), 0.92)
            let x = min(max(midX - width / 2, 0), 1 - width)
            let y = min(max(topY, 0), 1 - height)
            return TryOnRect(x: x, y: y, width: width, height: height)
        case .bottom:
            let topY = min(
                landmarks.waistCenter?.y ?? 0.46,
                landmarks.leftHip?.y ?? landmarks.rightHip?.y ?? 0.48
            ) - 0.01
            let ankleY = max(
                landmarks.leftAnkle?.y ?? landmarks.rightAnkle?.y ?? 0.94,
                topY + 0.28
            )
            let bottomY = min(ankleY + 0.04, 0.99)
            let hipSpan = abs((landmarks.rightHip?.x ?? right) - (landmarks.leftHip?.x ?? left))
            let width = min(max(max(hipSpan, shoulderSpan * 0.72) + horizontalPad, 0.36), 0.78)
            let height = max(bottomY - topY, 0.28)
            let x = min(max(midX - width / 2, 0), 1 - width)
            let y = min(max(topY, 0), 1 - height)
            return TryOnRect(x: x, y: y, width: width, height: height)
        case .shoes:
            let kneeY = max(
                landmarks.leftKnee?.y ?? landmarks.rightKnee?.y ?? 0.82,
                0.78
            )
            let bottomY = 0.99
            let ankleLeft = landmarks.leftAnkle?.x ?? midX - shoulderSpan * 0.22
            let ankleRight = landmarks.rightAnkle?.x ?? midX + shoulderSpan * 0.22
            let footSpan = max(abs(ankleRight - ankleLeft), shoulderSpan * 0.38)
            let width = min(max(footSpan + horizontalPad * 0.5, 0.28), 0.56)
            let height = max(bottomY - kneeY, 0.10)
            let x = min(max(midX - width / 2, 0), 1 - width)
            let y = min(max(kneeY, 0), 1 - height)
            return TryOnRect(x: x, y: y, width: width, height: height)
        case .headwear:
            let topY = 0.04
            let neckY = landmarks.neckCenter?.y ?? 0.18
            let bottomY = min(neckY + 0.02, topY + 0.18)
            let width = min(max(shoulderSpan * 0.75, 0.22), 0.50)
            let height = max(bottomY - topY, 0.08)
            let x = min(max(midX - width / 2, 0), 1 - width)
            return TryOnRect(x: x, y: topY, width: width, height: height)
        }
    }
}

struct TryOnLandmarks: Codable, Equatable {
    var neckCenter: TryOnPoint?
    var leftShoulderJoint: TryOnPoint?
    var rightShoulderJoint: TryOnPoint?
    var leftShoulderEdge: TryOnPoint?
    var rightShoulderEdge: TryOnPoint?
    var leftArmpit: TryOnPoint?
    var rightArmpit: TryOnPoint?
    var leftElbow: TryOnPoint?
    var rightElbow: TryOnPoint?
    var leftWrist: TryOnPoint?
    var rightWrist: TryOnPoint?
    var chestCenter: TryOnPoint?
    var waistCenter: TryOnPoint?
    var leftWaist: TryOnPoint?
    var rightWaist: TryOnPoint?
    var leftHip: TryOnPoint?
    var rightHip: TryOnPoint?
    var crotchCenter: TryOnPoint?
    var leftKnee: TryOnPoint?
    var rightKnee: TryOnPoint?
    var leftAnkle: TryOnPoint?
    var rightAnkle: TryOnPoint?

    func point(named name: String) -> TryOnPoint? {
        switch name {
        case "neckCenter": return neckCenter
        case "leftShoulderJoint": return leftShoulderJoint
        case "rightShoulderJoint": return rightShoulderJoint
        case "leftShoulderEdge": return leftShoulderEdge
        case "rightShoulderEdge": return rightShoulderEdge
        case "leftArmpit": return leftArmpit
        case "rightArmpit": return rightArmpit
        case "leftElbow": return leftElbow
        case "rightElbow": return rightElbow
        case "leftWrist": return leftWrist
        case "rightWrist": return rightWrist
        case "chestCenter": return chestCenter
        case "waistCenter": return waistCenter
        case "leftWaist": return leftWaist
        case "rightWaist": return rightWaist
        case "leftHip": return leftHip
        case "rightHip": return rightHip
        case "crotchCenter": return crotchCenter
        case "leftKnee": return leftKnee
        case "rightKnee": return rightKnee
        case "leftAnkle": return leftAnkle
        case "rightAnkle": return rightAnkle
        default: return nil
        }
    }

    /// Present landmarks only. Absent joints are omitted rather than filled in.
    var present: [String: TryOnPoint] {
        let names = [
            "neckCenter", "leftShoulderJoint", "rightShoulderJoint", "leftShoulderEdge",
            "rightShoulderEdge", "leftArmpit", "rightArmpit", "leftElbow", "rightElbow",
            "leftWrist", "rightWrist", "chestCenter", "waistCenter", "leftWaist", "rightWaist",
            "leftHip", "rightHip", "crotchCenter", "leftKnee", "rightKnee", "leftAnkle", "rightAnkle"
        ]
        var found: [String: TryOnPoint] = [:]
        for name in names {
            if let point = point(named: name) {
                found[name] = point
            }
        }
        return found
    }
}

struct TryOnSemanticMasks: Codable, Equatable {
    var headPath: String?
    var hairBackPath: String?
    var hairFrontPath: String?
    var neckPath: String?
    var torsoPath: String?
    var leftUpperArmPath: String?
    var rightUpperArmPath: String?
    var leftForearmPath: String?
    var rightForearmPath: String?
    var leftHandPath: String?
    var rightHandPath: String?
    var pelvisPath: String?
    var leftLegPath: String?
    var rightLegPath: String?
    var silhouettePath: String?

    init(
        headPath: String? = nil, hairBackPath: String? = nil, hairFrontPath: String? = nil,
        neckPath: String? = nil, torsoPath: String? = nil, leftUpperArmPath: String? = nil,
        rightUpperArmPath: String? = nil, leftForearmPath: String? = nil, rightForearmPath: String? = nil,
        leftHandPath: String? = nil, rightHandPath: String? = nil, pelvisPath: String? = nil,
        leftLegPath: String? = nil, rightLegPath: String? = nil, silhouettePath: String? = nil
    ) {
        self.headPath = headPath
        self.hairBackPath = hairBackPath
        self.hairFrontPath = hairFrontPath
        self.neckPath = neckPath
        self.torsoPath = torsoPath
        self.leftUpperArmPath = leftUpperArmPath
        self.rightUpperArmPath = rightUpperArmPath
        self.leftForearmPath = leftForearmPath
        self.rightForearmPath = rightForearmPath
        self.leftHandPath = leftHandPath
        self.rightHandPath = rightHandPath
        self.pelvisPath = pelvisPath
        self.leftLegPath = leftLegPath
        self.rightLegPath = rightLegPath
        self.silhouettePath = silhouettePath
    }
}

struct TryOnAvatarLayers: Codable, Equatable {
    var bodyBasePath: String?
    var backHairPath: String?
    var backArmsPath: String?
    var frontArmsPath: String?
    var frontHairPath: String?
    var faceForegroundPath: String?
}

struct TryOnFittingMap: Codable, Equatable {
    var landmarks: TryOnLandmarks
    var masks: TryOnSemanticMasks
}

struct TryOnValidationReport: Codable, Equatable {
    var status: String
    var checks: [TryOnCheck]

    var requiredFailures: [TryOnCheck] { checks.filter { $0.level == .required && !$0.passed } }
    var reviewFailures: [TryOnCheck] { checks.filter { $0.level == .review && !$0.passed } }

    static let empty = TryOnValidationReport(status: "pending", checks: [])
}

enum TryOnCheckLevel: String, Codable, Equatable {
    case required
    case review
}

struct TryOnCheck: Codable, Equatable, Identifiable {
    var id: String
    var level: TryOnCheckLevel
    var passed: Bool
    var message: String
}

struct TryOnAvatar: Codable, Equatable, Identifiable {
    var id: String
    var version: Int
    var canvas: TryOnCanvas
    var canonicalImagePath: String
    var layers: TryOnAvatarLayers
    var fittingMap: TryOnFittingMap
    var styleVersion: String
    var promptVersion: String
    var providerVersion: String
    var status: TryOnJobStatus
    var validation: TryOnValidationReport
    var createdAt: Date
    var updatedAt: Date
}

enum TryOnComponentKind: String, Codable, Equatable {
    case rearPanel
    case hood
    case mainBody
    case leftSleeve
    case rightSleeve
    case leftFrontPanel
    case rightFrontPanel
    case leftLeg
    case rightLeg
    case foregroundDetail
    case generic
}

enum TryOnDepthGroup: String, Codable, Equatable {
    case behindAvatar
    case clothing
    case inFrontOfAvatar
}

struct TryOnGarmentComponent: Codable, Equatable, Identifiable {
    var id: String
    var kind: TryOnComponentKind
    var imagePath: String
    var alphaMaskPath: String?
    var canvas: TryOnCanvas
    var depthGroup: TryOnDepthGroup
    var defaultRenderOrder: Int
}

struct TryOnEase: Codable, Equatable {
    var maxLocalDisplacement: Double
    var shoulderDrop: Double
}

struct TryOnGarmentFit: Codable, Equatable {
    var templateId: String
    var fitStyle: String?
    var preserveSilhouette: Bool
    var ease: TryOnEase
    var upperTemplateId: String?
    var bypassedUpperTemplate: Bool
}

struct TryOnGarmentAsset: Codable, Equatable, Identifiable {
    var id: String
    var userID: String
    var avatarID: String
    var avatarVersion: Int
    var originalImagePath: String
    var fittedReferencePath: String?
    /// Full-canvas body-region layer from `GarmentBodyPartService` (primary fitting path).
    var bodyPartImagePath: String?
    var bodyPartGenerationVersion: String?
    var components: [TryOnGarmentComponent]
    var anchors: [String: TryOnPoint]
    var contentBounds: TryOnRect
    var fit: TryOnGarmentFit
    var meshPath: String?
    var occlusionPath: String?
    var sourceCategory: String
    /// Closet display name when the asset was fitted; used for scarf vs hat slot resolution.
    var sourceName: String?
    var processingVersion: Int
    var styleVersion: String
    var promptVersion: String
    var providerVersion: String
    var attemptCount: Int
    var status: TryOnJobStatus
    var validation: TryOnValidationReport
    var createdAt: Date
    var updatedAt: Date

    var tryOnBodySlot: TryOnBodySlot? {
        guard let category = ClothingCategory(rawValue: sourceCategory) else { return nil }
        return TryOnBodySlot.slot(for: category, name: sourceName)
    }
}

struct TryOnGarmentPlacement: Codable, Equatable {
    var garmentID: String
    var translation: TryOnPoint
    var scaleX: Double
    var scaleY: Double
    var rotationDegrees: Double
    var visible: Bool

    static func identity(garmentID: String) -> TryOnGarmentPlacement {
        TryOnGarmentPlacement(
            garmentID: garmentID,
            translation: .zero,
            scaleX: 1,
            scaleY: 1,
            rotationDegrees: 0,
            visible: true
        )
    }
}

struct TryOnComponentOverride: Codable, Equatable {
    var garmentID: String
    var componentID: String
    var renderOrder: Int?
    var visible: Bool
}

struct TryOnOutfit: Codable, Equatable, Identifiable {
    var id: String
    var userID: String
    var avatarID: String
    var name: String
    var selectedGarmentIDs: [String]
    var placements: [TryOnGarmentPlacement]
    var componentOverrides: [TryOnComponentOverride]
    /// Full-body front composite with garments baked in (per-outfit display layer).
    var compositeImagePath: String?
    /// Garment IDs whose clothing is painted into `compositeImagePath`.
    var compositeBakedGarmentIDs: [String]?
    var compositeProcessingVersion: Int?
    var revision: Int
    var createdAt: Date
    var updatedAt: Date

    func placement(for garmentID: String) -> TryOnGarmentPlacement {
        placements.first { $0.garmentID == garmentID } ?? .identity(garmentID: garmentID)
    }

    var compositeDisplayActive: Bool {
        guard compositeImagePath != nil else { return false }
        guard compositeProcessingVersion == TryOnVersions.processing
            || compositeProcessingVersion == TryOnVersions.bodyPartProcessing
            || compositeProcessingVersion == TryOnVersions.alignedOutfitProcessing else { return false }
        let baked = Set(compositeBakedGarmentIDs ?? [])
        let worn = Set(selectedGarmentIDs)
        return !baked.isEmpty && baked.isSubset(of: worn)
    }

    var bodyPartFittingActive: Bool {
        compositeDisplayActive && compositeProcessingVersion == TryOnVersions.bodyPartProcessing
    }

    var alignedOutfitFittingActive: Bool {
        compositeDisplayActive && compositeProcessingVersion == TryOnVersions.alignedOutfitProcessing
    }
}

enum TryOnVertexConstraint: String, Codable, Equatable {
    case flexible
    case edge
    case seam
    case protected
}

struct TryOnMeshVertex: Codable, Equatable {
    var x: Float
    var y: Float
    var u: Float
    var v: Float
    var constraint: TryOnVertexConstraint
}

struct TryOnDeformationRegion: Codable, Equatable {
    var id: String
    var regionType: String
    var vertexIndices: [Int]
    var maxDisplacement: Double
}

struct TryOnMesh: Codable, Equatable {
    var vertices: [TryOnMeshVertex]
    var indices: [UInt32]
    var regions: [TryOnDeformationRegion]
}

enum TryOnPose: String, Codable, CaseIterable, Identifiable {
    case front
    case threeQuarter
    case side
    case back
    case walking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .front: return "Front"
        case .threeQuarter: return "Three-quarter"
        case .side: return "Side"
        case .back: return "Back"
        case .walking: return "Walking"
        }
    }

    var instruction: String {
        switch self {
        case .front: return "Front view, neutral standing pose, full body."
        case .threeQuarter: return "Three-quarter view, turned about 45 degrees, full body."
        case .side: return "Side view, full body."
        case .back: return "Back view, full body."
        case .walking: return "Walking pose, full body, one step."
        }
    }
}

enum TryOnCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

enum TryOnTransform {
    static func forward(_ point: TryOnPoint, pivot: TryOnPoint, placement: TryOnGarmentPlacement) -> TryOnPoint {
        let radians = placement.rotationDegrees * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        let dx = (point.x - pivot.x) * placement.scaleX
        let dy = (point.y - pivot.y) * placement.scaleY
        return TryOnPoint(
            x: dx * cosine - dy * sine + pivot.x + placement.translation.x,
            y: dx * sine + dy * cosine + pivot.y + placement.translation.y
        )
    }

    static func inverse(_ point: TryOnPoint, pivot: TryOnPoint, placement: TryOnGarmentPlacement) -> TryOnPoint {
        let radians = placement.rotationDegrees * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        let rx = point.x - placement.translation.x - pivot.x
        let ry = point.y - placement.translation.y - pivot.y
        let dx = rx * cosine + ry * sine
        let dy = -rx * sine + ry * cosine
        let scaleX = abs(placement.scaleX) < 0.0001 ? 0.0001 : placement.scaleX
        let scaleY = abs(placement.scaleY) < 0.0001 ? 0.0001 : placement.scaleY
        return TryOnPoint(x: dx / scaleX + pivot.x, y: dy / scaleY + pivot.y)
    }
}
