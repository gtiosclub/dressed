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
    static let poseSet = "poses-v1"
    static let provider = "gpt-image-2.5-sunburst"
    static let processing = 8
    static let maxLocalDisplacement = 0.02
}

/// Non-overlapping body regions for layered avatar try-on. Changing one slot must preserve the others.
enum TryOnBodySlot: String, Codable, CaseIterable {
    case top
    case bottom
    case shoes
    case headwear

    static func slot(for category: ClothingCategory) -> TryOnBodySlot? {
        switch category {
        case .tops, .outerwear: return .top
        case .pants, .skirts, .dresses: return .bottom
        case .shoes: return .shoes
        case .accessories: return .headwear
        case .other: return nil
        }
    }

    var displayName: String {
        switch self {
        case .top: return "top"
        case .bottom: return "bottom"
        case .shoes: return "shoes"
        case .headwear: return "headwear"
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
    var components: [TryOnGarmentComponent]
    var anchors: [String: TryOnPoint]
    var contentBounds: TryOnRect
    var fit: TryOnGarmentFit
    var meshPath: String?
    var occlusionPath: String?
    var sourceCategory: String
    var processingVersion: Int
    var styleVersion: String
    var promptVersion: String
    var providerVersion: String
    var attemptCount: Int
    var status: TryOnJobStatus
    var validation: TryOnValidationReport
    var createdAt: Date
    var updatedAt: Date
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
        guard compositeImagePath != nil,
              compositeProcessingVersion == TryOnVersions.processing else { return false }
        let baked = Set(compositeBakedGarmentIDs ?? [])
        let worn = Set(selectedGarmentIDs)
        return !baked.isEmpty && baked.isSubset(of: worn)
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
