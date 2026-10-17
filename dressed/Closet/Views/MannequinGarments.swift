import Foundation

// Procedural 3D fashion garment meshes for the avatar mannequin.
// Each garment is lofted to comfortably drape over the mannequin body shape.
// Proportions calculated from clothing piece imagery dynamically adjust fit, drop, and flare.
// Framing matches Mannequin.swift: 1 unit tall, feet at y = 0, facing +z.

enum MannequinGarments {
    static func mesh(
        for category: ClothingCategory,
        shape: BodyShape,
        proportions: GarmentProportions = GarmentProportions()
    ) -> MannequinMesh {
        switch category {
        case .tops:
            return tops(shape: shape, proportions: proportions)
        case .pants:
            return pants(shape: shape, proportions: proportions)
        case .skirts:
            return skirts(shape: shape, proportions: proportions)
        case .dresses:
            return dresses(shape: shape, proportions: proportions)
        case .outerwear:
            return outerwear(shape: shape, proportions: proportions)
        case .shoes:
            return shoes(shape: shape, proportions: proportions)
        case .accessories:
            return accessories(shape: shape)
        case .other:
            return vest(shape: shape)
        }
    }

    // MARK: - Tops (Shirt / Blouse / Tee)

    static func tops(shape: BodyShape, proportions: GarmentProportions = GarmentProportions()) -> MannequinMesh {
        let lowerWaist = (shape.hips + shape.waist) / 2
        let upperWaist = (shape.waist + shape.bust) / 2
        let inflate: Float = 1.05 * proportions.widthRatio
        let offset: Float = 0.003
        let drop = 0.635 - 0.045 * proportions.lengthRatio
        let shoulderScale = proportions.shoulderSpan

        let keys = [
            LoftRing([0, drop, -0.003], width: (0.077 * lowerWaist) * inflate + offset, depth: (0.050 * lowerWaist) * inflate + offset),
            LoftRing([0, 0.635, 0], width: (0.065 * shape.waist) * inflate + offset, depth: (0.045 * shape.waist) * inflate + offset),
            LoftRing([0, 0.69, 0.003], width: (0.076 * upperWaist) * inflate + offset, depth: (0.050 * upperWaist) * inflate + offset),
            LoftRing([0, 0.735, 0.006], width: (0.085 * shape.bust) * inflate + offset, depth: (0.056 * shape.bust) * inflate + offset),
            LoftRing([0, 0.78, 0.002], width: (0.094 * shape.shoulders * shoulderScale) * inflate + offset, depth: (0.050 * shape.bust) * inflate + offset),
            LoftRing([0, 0.815, -0.003], width: (0.096 * shape.shoulders * shoulderScale) * inflate + offset, depth: (0.042 * shape.bust) * inflate + offset)
        ]
        var mesh = MannequinGeometry.loft(keys, sides: 36, caps: (start: 0.012, end: 0.015))
        for side: Float in [-1, 1] {
            mesh.append(shortSleeve(shape: shape, side: side, proportions: proportions))
        }
        return mesh
    }

    private static func shortSleeve(shape: BodyShape, side: Float, proportions: GarmentProportions) -> MannequinMesh {
        let limbs = shape.limbs
        let shoulderX = 0.1 * shape.shoulders * proportions.shoulderSpan
        let inflate: Float = 1.08 * proportions.widthRatio
        let offset: Float = 0.0025
        let sleeveLength = proportions.lengthRatio
        let sleeveEnd = 0.725 - 0.055 * sleeveLength

        let keys = [
            LoftRing([side * shoulderX, 0.805, -0.004], width: (0.026 * limbs) * inflate + offset, depth: (0.028 * limbs) * inflate + offset),
            LoftRing([side * (shoulderX + 0.008), 0.725, -0.006], width: (0.022 * limbs) * inflate + offset, depth: (0.024 * limbs) * inflate + offset),
            LoftRing([side * (shoulderX + 0.012), sleeveEnd, -0.008], width: (0.020 * limbs) * inflate + offset, depth: (0.021 * limbs) * inflate + offset)
        ]
        return MannequinGeometry.loft(keys, sides: 20, caps: (start: 0.015, end: 0.01))
    }

    // MARK: - Pants (Trousers / Jeans)

    static func pants(shape: BodyShape, proportions: GarmentProportions = GarmentProportions()) -> MannequinMesh {
        var mesh = MannequinMesh()
        let lowerWaist = (shape.hips + shape.waist) / 2
        let waistbandKeys = [
            LoftRing([0, 0.50, -0.006], width: 0.095 * shape.hips * 1.04, depth: 0.059 * shape.hips * 1.04),
            LoftRing([0, 0.54, -0.005], width: 0.097 * shape.hips * 1.04, depth: 0.061 * shape.hips * 1.04),
            LoftRing([0, 0.59, -0.003], width: 0.080 * lowerWaist * 1.04, depth: 0.052 * lowerWaist * 1.04),
            LoftRing([0, 0.64, 0], width: 0.068 * shape.waist * 1.04, depth: 0.047 * shape.waist * 1.04)
        ]
        mesh.append(MannequinGeometry.loft(waistbandKeys, sides: 32, caps: (start: 0.01, end: 0.01)))
        for side: Float in [-1, 1] {
            mesh.append(pantLeg(shape: shape, side: side, proportions: proportions))
        }
        return mesh
    }

    private static func pantLeg(shape: BodyShape, side: Float, proportions: GarmentProportions) -> MannequinMesh {
        let thigh = (shape.hips + shape.limbs) / 2
        let limbs = shape.limbs
        let hipX = max(0.05 * shape.hips, 0.046 * thigh + 0.003)
        let inflate: Float = 1.07 * proportions.widthRatio
        let offset: Float = 0.003
        let fullness = proportions.fullness

        let keys = [
            LoftRing([side * hipX, 0.52, -0.004], width: (0.040 * thigh) * inflate + offset, depth: (0.044 * thigh) * inflate + offset),
            LoftRing([side * hipX, 0.47, -0.003], width: (0.048 * thigh) * inflate + offset, depth: (0.050 * thigh) * inflate + offset),
            LoftRing([side * hipX * 0.96, 0.38, 0], width: (0.040 * thigh) * inflate + offset, depth: (0.042 * thigh) * inflate + offset),
            LoftRing([side * 0.044, 0.285, 0.002], width: (0.026 * limbs) * inflate * fullness + offset, depth: (0.028 * limbs) * inflate * fullness + offset),
            LoftRing([side * 0.044, 0.21, -0.005], width: (0.030 * limbs) * inflate * fullness + offset, depth: (0.033 * limbs) * inflate * fullness + offset),
            LoftRing([side * 0.044, 0.12, -0.002], width: (0.021 * limbs) * inflate * fullness + offset, depth: (0.022 * limbs) * inflate * fullness + offset),
            LoftRing([side * 0.045, 0.05, -0.004], width: (0.018 * limbs) * inflate * fullness + offset, depth: (0.019 * limbs) * inflate * fullness + offset)
        ]
        return MannequinGeometry.loft(keys, sides: 24, caps: (start: 0.02, end: 0.012))
    }

    // MARK: - Skirts

    static func skirts(shape: BodyShape, proportions: GarmentProportions = GarmentProportions()) -> MannequinMesh {
        let lowerWaist = (shape.hips + shape.waist) / 2
        let flare = proportions.fullness
        let hemY = 0.64 - (0.64 - 0.36) * proportions.lengthRatio
        let midY = (0.64 + hemY) / 2

        let keys = [
            LoftRing([0, hemY, 0.002], width: 0.130 * shape.hips * flare, depth: 0.088 * shape.hips * flare),
            LoftRing([0, midY, 0.001], width: 0.114 * shape.hips * flare, depth: 0.075 * shape.hips * flare),
            LoftRing([0, 0.54, -0.005], width: 0.098 * shape.hips, depth: 0.062 * shape.hips),
            LoftRing([0, 0.59, -0.003], width: 0.082 * lowerWaist, depth: 0.054 * lowerWaist),
            LoftRing([0, 0.64, 0], width: 0.069 * shape.waist, depth: 0.048 * shape.waist)
        ]
        return MannequinGeometry.loft(keys, sides: 36, caps: (start: 0.012, end: 0.012))
    }

    // MARK: - Dresses

    static func dresses(shape: BodyShape, proportions: GarmentProportions = GarmentProportions()) -> MannequinMesh {
        let lowerWaist = (shape.hips + shape.waist) / 2
        let upperWaist = (shape.waist + shape.bust) / 2
        let flare = proportions.fullness
        let hemY = 0.635 - (0.635 - 0.38) * proportions.lengthRatio
        let widthScale = proportions.widthRatio

        let keys = [
            LoftRing([0, hemY, 0.002], width: 0.125 * shape.hips * flare * widthScale, depth: 0.082 * shape.hips * flare * widthScale),
            LoftRing([0, 0.46, -0.002], width: 0.108 * shape.hips * flare * widthScale, depth: 0.070 * shape.hips * flare * widthScale),
            LoftRing([0, 0.54, -0.005], width: 0.098 * shape.hips * widthScale, depth: 0.062 * shape.hips * widthScale),
            LoftRing([0, 0.59, -0.003], width: 0.082 * lowerWaist * widthScale, depth: 0.054 * lowerWaist * widthScale),
            LoftRing([0, 0.635, 0], width: 0.068 * shape.waist * widthScale, depth: 0.047 * shape.waist * widthScale),
            LoftRing([0, 0.69, 0.003], width: 0.079 * upperWaist * widthScale, depth: 0.053 * upperWaist * widthScale),
            LoftRing([0, 0.735, 0.006], width: 0.088 * shape.bust * widthScale, depth: 0.059 * shape.bust * widthScale),
            LoftRing([0, 0.78, 0.002], width: 0.097 * shape.shoulders * widthScale, depth: 0.053 * shape.bust * widthScale),
            LoftRing([0, 0.81, -0.003], width: 0.099 * shape.shoulders * widthScale, depth: 0.045 * shape.bust * widthScale)
        ]
        return MannequinGeometry.loft(keys, sides: 36, caps: (start: 0.014, end: 0.015))
    }

    // MARK: - Outerwear (Coats / Jackets)

    static func outerwear(shape: BodyShape, proportions: GarmentProportions = GarmentProportions()) -> MannequinMesh {
        let lowerWaist = (shape.hips + shape.waist) / 2
        let upperWaist = (shape.waist + shape.bust) / 2
        let inflate: Float = 1.10 * proportions.widthRatio
        let offset: Float = 0.005
        let hemY = 0.635 - (0.635 - 0.52) * proportions.lengthRatio

        let keys = [
            LoftRing([0, hemY, -0.006], width: (0.095 * shape.hips) * inflate + offset, depth: (0.058 * shape.hips) * inflate + offset),
            LoftRing([0, 0.585, -0.003], width: (0.077 * lowerWaist) * inflate + offset, depth: (0.050 * lowerWaist) * inflate + offset),
            LoftRing([0, 0.635, 0], width: (0.065 * shape.waist) * inflate + offset, depth: (0.045 * shape.waist) * inflate + offset),
            LoftRing([0, 0.69, 0.003], width: (0.076 * upperWaist) * inflate + offset, depth: (0.050 * upperWaist) * inflate + offset),
            LoftRing([0, 0.735, 0.006], width: (0.085 * shape.bust) * inflate + offset, depth: (0.056 * shape.bust) * inflate + offset),
            LoftRing([0, 0.78, 0.002], width: (0.094 * shape.shoulders) * inflate + offset, depth: (0.050 * shape.bust) * inflate + offset),
            LoftRing([0, 0.82, -0.003], width: (0.098 * shape.shoulders) * inflate + offset, depth: (0.045 * shape.bust) * inflate + offset)
        ]
        var mesh = MannequinGeometry.loft(keys, sides: 36, caps: (start: 0.015, end: 0.018))
        for side: Float in [-1, 1] {
            mesh.append(fullSleeve(shape: shape, side: side, proportions: proportions))
        }
        return mesh
    }

    private static func fullSleeve(shape: BodyShape, side: Float, proportions: GarmentProportions) -> MannequinMesh {
        let limbs = shape.limbs
        let shoulderX = 0.1 * shape.shoulders
        let inflate: Float = 1.12 * proportions.widthRatio
        let offset: Float = 0.004
        let keys = [
            LoftRing([side * shoulderX, 0.805, -0.004], width: (0.026 * limbs) * inflate + offset, depth: (0.028 * limbs) * inflate + offset),
            LoftRing([side * (shoulderX + 0.008), 0.725, -0.006], width: (0.022 * limbs) * inflate + offset, depth: (0.024 * limbs) * inflate + offset),
            LoftRing([side * (shoulderX + 0.015), 0.635, -0.01], width: (0.018 * limbs) * inflate + offset, depth: (0.019 * limbs) * inflate + offset),
            LoftRing([side * (shoulderX + 0.019), 0.585, -0.006], width: (0.019 * limbs) * inflate + offset, depth: (0.019 * limbs) * inflate + offset),
            LoftRing([side * wristX(shape), 0.515, 0], width: (0.015 * limbs) * inflate + offset, depth: (0.014 * limbs) * inflate + offset)
        ]
        return MannequinGeometry.loft(keys, sides: 20, caps: (start: 0.02, end: 0.01))
    }

    private static func wristX(_ shape: BodyShape) -> Float {
        0.1 * shape.shoulders + 0.025 + max(0, shape.hips - 1) * 0.06
    }

    // MARK: - Shoes

    static func shoes(shape: BodyShape, proportions: GarmentProportions = GarmentProportions()) -> MannequinMesh {
        var mesh = MannequinMesh()
        for side: Float in [-1, 1] {
            mesh.append(shoe(shape: shape, side: side, proportions: proportions))
        }
        return mesh
    }

    private static func shoe(shape: BodyShape, side: Float, proportions: GarmentProportions) -> MannequinMesh {
        let size = (1 + shape.limbs) / 2
        let footX = side * 0.045
        let inflate: Float = 1.15 * proportions.widthRatio
        let bootHeight = 0.020 * proportions.lengthRatio
        let keys = [
            LoftRing([footX, bootHeight, -0.024], width: 0.018 * size * inflate, depth: 0.019 * inflate),
            LoftRing([footX, 0.019, 0.012], width: 0.024 * size * inflate, depth: 0.017 * inflate),
            LoftRing([footX * 1.02, 0.013, 0.058], width: 0.028 * size * inflate, depth: 0.013 * inflate),
            LoftRing([footX * 1.05, 0.010, 0.086], width: 0.024 * size * inflate, depth: 0.010 * inflate)
        ]
        return MannequinGeometry.loft(keys, sides: 20, caps: (start: 0.014, end: 0.014), reference: [0, 1, 0])
    }

    // MARK: - Accessories (Belt / Scarf)

    static func accessories(shape: BodyShape) -> MannequinMesh {
        let keys = [
            LoftRing([0, 0.62, 0], width: 0.070 * shape.waist, depth: 0.049 * shape.waist),
            LoftRing([0, 0.645, 0], width: 0.069 * shape.waist, depth: 0.048 * shape.waist)
        ]
        return MannequinGeometry.loft(keys, sides: 32, caps: (start: 0.005, end: 0.005))
    }

    // MARK: - Vest / Other

    static func vest(shape: BodyShape) -> MannequinMesh {
        let lowerWaist = (shape.hips + shape.waist) / 2
        let upperWaist = (shape.waist + shape.bust) / 2
        let inflate: Float = 1.06
        let offset: Float = 0.003
        let keys = [
            LoftRing([0, 0.60, -0.003], width: (0.077 * lowerWaist) * inflate + offset, depth: (0.050 * lowerWaist) * inflate + offset),
            LoftRing([0, 0.64, 0], width: (0.065 * shape.waist) * inflate + offset, depth: (0.045 * shape.waist) * inflate + offset),
            LoftRing([0, 0.70, 0.003], width: (0.076 * upperWaist) * inflate + offset, depth: (0.050 * upperWaist) * inflate + offset),
            LoftRing([0, 0.75, 0.006], width: (0.085 * shape.bust) * inflate + offset, depth: (0.056 * shape.bust) * inflate + offset),
            LoftRing([0, 0.80, 0.002], width: (0.094 * shape.shoulders) * inflate + offset, depth: (0.050 * shape.bust) * inflate + offset)
        ]
        return MannequinGeometry.loft(keys, sides: 36, caps: (start: 0.01, end: 0.012))
    }
}
