import Foundation

// Procedural 3D garment preset meshes for the avatar mannequin.
// Framing matches Mannequin.swift: 1 unit tall, feet at y = 0, facing +z.
//
// How the fit works: each garment is built from the mannequin's own key rings (copied in `BodyReference`
// at the bottom of this file) with the same Catmull-Rom smoothing, pushed out by an even `ease` in units
// (1 unit = the avatar's height, so 0.005 is about 9 mm on a 1.75 m person). Because the garment follows
// the same rings as the skin, the gap to the body is that ease everywhere, on every body preset:
// no gaps, and no skin poking through.
//
// Layering: tops and dresses use more ease than bottoms (bottoms <= 0.005, tops over bottoms >= 0.0065),
// so a waistband never shows through a hem worn over it.

enum MannequinGarments {

    /// Builds the 3D mesh for any GarmentPreset.
    static func mesh(for preset: GarmentPreset, shape: BodyShape) -> MannequinMesh {
        switch preset {
        // Tops with full shoulder coverage
        case .tShirt: return tShirtMesh(shape: shape)
        case .hoodie: return hoodieMesh(shape: shape)
        case .sweater: return sweaterMesh(shape: shape)
        case .sweatshirt: return sweatshirtMesh(shape: shape)
        case .jersey: return jerseyMesh(shape: shape)
        case .blouse: return blouseMesh(shape: shape)
        // Tops with exposed shoulders / minimal coverage
        case .tankTop: return tankTopMesh(shape: shape)
        case .cropTop: return cropTopMesh(shape: shape)
        case .bikini: return bikiniMesh(shape: shape)
        // Bottoms
        case .jeans: return jeansMesh(shape: shape)
        case .pants: return trousersMesh(shape: shape)
        case .shorts: return shortsMesh(shape: shape)
        case .capris: return caprisMesh(shape: shape)
        case .leggings: return leggingsMesh(shape: shape)
        // One-piece & Skirts
        case .skirt: return skirtMesh(shape: shape)
        case .dress: return dressMesh(shape: shape)
        case .longDress: return longDressMesh(shape: shape)
        // Accessories & Shoes
        case .beanie: return beanieMesh(shape: shape)
        case .sneakers: return sneakersMesh(shape: shape)
        case .boots: return bootsMesh(shape: shape)
        }
    }

    /// Backwards-compatible overload for ClothingCategory.
    static func mesh(
        for category: ClothingCategory,
        shape: BodyShape,
        proportions: GarmentProportions = GarmentProportions()
    ) -> MannequinMesh {
        switch category {
        case .tops: return tShirtMesh(shape: shape)
        case .pants: return jeansMesh(shape: shape)
        case .skirts: return skirtMesh(shape: shape)
        case .dresses: return dressMesh(shape: shape)
        case .outerwear: return hoodieMesh(shape: shape)
        case .shoes: return sneakersMesh(shape: shape)
        case .accessories: return beanieMesh(shape: shape)
        case .other: return tShirtMesh(shape: shape)
        }
    }

    // MARK: - Tops
    // Tuning knobs per top: hemY (where the hem sits), sleeveEnd (where the sleeve stops; the wrist is at 0.505,
    // the elbow at 0.635, the shoulder at 0.80) and ease (how far the fabric stands off the skin).

    /// T-Shirt: hem over the hips so it covers the pants waistband, short sleeves.
    static func tShirtMesh(shape: BodyShape) -> MannequinMesh {
        var mesh = GarmentFit.torsoShell(shape, hemY: 0.520, ease: 0.0075)
        for side: Float in [-1, 1] {
            mesh.append(GarmentFit.sleeve(shape, side: side, endY: 0.755, ease: 0.0075, flare: 0.0025))
        }
        return mesh
    }

    /// Hoodie: relaxed fit, long sleeves, kangaroo pocket and a hood resting behind the neck.
    static func hoodieMesh(shape: BodyShape) -> MannequinMesh {
        let ease: Float = 0.0110
        var mesh = GarmentFit.torsoShell(shape, hemY: 0.580, ease: ease)
        for side: Float in [-1, 1] {
            mesh.append(GarmentFit.sleeve(shape, side: side, endY: 0.510, ease: ease, flare: 0.0010))
        }
        // Kangaroo pocket: a shallow pouch sitting about 3 mm proud of the hoodie front.
        let pocketKeys = [0.610, 0.655].map { (height: Float) -> LoftRing in
            let front = GarmentFit.frontRing(shape, atY: height, ease: ease)
            let frontZ = front.center.z + front.depth - 0.0075
            return LoftRing([0, height, frontZ], width: front.width * 0.62, depth: 0.0105)
        }
        mesh.append(MannequinGeometry.loft(pocketKeys, sides: 24, caps: (start: 0.008, end: 0.008)))

        // Hood resting draped behind the neck and upper back.
        let neckScale = (1 + shape.limbs) / 2 * shape.neck
        let back = GarmentFit.backZ(shape, atY: 0.80)
        let hoodKeys = [
            LoftRing([0, 0.825, back - 0.006], width: 0.055 * neckScale, depth: 0.026),
            LoftRing([0, 0.855, back - 0.022], width: 0.062 * neckScale, depth: 0.034),
            LoftRing([0, 0.880, back - 0.017], width: 0.058 * neckScale, depth: 0.032),
            LoftRing([0, 0.900, back], width: 0.046 * neckScale, depth: 0.024)
        ]
        mesh.append(MannequinGeometry.loft(hoodKeys, sides: 24, caps: (start: 0.012, end: 0.012)))
        return mesh
    }

    /// Sweater: knitted fit, long sleeves, hem just above the hips.
    static func sweaterMesh(shape: BodyShape) -> MannequinMesh {
        var mesh = GarmentFit.torsoShell(shape, hemY: 0.590, ease: 0.0085)
        for side: Float in [-1, 1] {
            mesh.append(GarmentFit.sleeve(shape, side: side, endY: 0.512, ease: 0.0085, flare: 0.0010))
        }
        return mesh
    }

    /// Sweatshirt: crew neck, long sleeves, a touch looser than the sweater.
    static func sweatshirtMesh(shape: BodyShape) -> MannequinMesh {
        var mesh = GarmentFit.torsoShell(shape, hemY: 0.585, ease: 0.0095)
        for side: Float in [-1, 1] {
            mesh.append(GarmentFit.sleeve(shape, side: side, endY: 0.512, ease: 0.0095, flare: 0.0010))
        }
        return mesh
    }

    /// Jersey: athletic cut, long body that falls straight over the hips and the pants, wide short sleeves.
    static func jerseyMesh(shape: BodyShape) -> MannequinMesh {
        var mesh = GarmentFit.torsoShell(shape, hemY: 0.455, ease: 0.0095)
        for side: Float in [-1, 1] {
            mesh.append(GarmentFit.sleeve(shape, side: side, endY: 0.720, ease: 0.0095, flare: 0.0045))
        }
        return mesh
    }

    /// Blouse: soft drape, three-quarter sleeves.
    static func blouseMesh(shape: BodyShape) -> MannequinMesh {
        var mesh = GarmentFit.torsoShell(shape, hemY: 0.590, ease: 0.0085)
        for side: Float in [-1, 1] {
            mesh.append(GarmentFit.sleeve(shape, side: side, endY: 0.560, ease: 0.0085, flare: 0.0030))
        }
        return mesh
    }

    /// Tank top: body up to the armholes and two narrow straps over the shoulders; outer shoulders stay bare.
    static func tankTopMesh(shape: BodyShape) -> MannequinMesh {
        let ease: Float = 0.0065
        var mesh = GarmentFit.torsoShell(shape, hemY: 0.620, topY: 0.800, ease: ease)
        // Straps sit just outside the neck, wider apart on thicker necks.
        let strapX = max(0.046, GarmentFit.neckHalfWidth(shape, atY: 0.82) + 0.012)
        for side: Float in [-1, 1] {
            mesh.append(GarmentFit.shoulderStrap(shape, atX: side * strapX, ease: 0.0010, halfWidth: 0.0085))
        }
        return mesh
    }

    /// Crop top: shoulders covered, midriff bare, short sleeves.
    static func cropTopMesh(shape: BodyShape) -> MannequinMesh {
        var mesh = GarmentFit.torsoShell(shape, hemY: 0.680, ease: 0.0055)
        for side: Float in [-1, 1] {
            mesh.append(GarmentFit.sleeve(shape, side: side, endY: 0.740, ease: 0.0055, flare: 0.0020))
        }
        return mesh
    }

    /// Bikini top: two triangle cups lying on the chest and a halter tied around the neck.
    static func bikiniMesh(shape: BodyShape) -> MannequinMesh {
        var mesh = MannequinMesh()
        for side: Float in [-1, 1] {
            let cup = GarmentFit.cup(shape, side: side, ease: 0.0025)
            mesh.append(cup.mesh)
            mesh.append(GarmentFit.halterStrap(shape, from: cup.apex, side: side, ease: 0.0025))
        }
        mesh.append(GarmentFit.neckBand(shape, atY: 0.846, ease: 0.0025))
        return mesh
    }

    // MARK: - Bottoms
    // Tuning knobs per bottom: waistY (top of the waistband; the natural waist is 0.635), hemY (ankle 0.04,
    // mid-calf 0.17, knee 0.285, mid-thigh 0.36), ease, and whether the leg falls straight below the knee.

    /// Jeans: straight leg, full length.
    static func jeansMesh(shape: BodyShape) -> MannequinMesh {
        GarmentFit.pants(shape, waistY: 0.638, hemY: 0.042, ease: 0.0045, straightLeg: true)
    }

    /// Pants: straight tailored trousers, full length.
    static func trousersMesh(shape: BodyShape) -> MannequinMesh {
        GarmentFit.pants(shape, waistY: 0.642, hemY: 0.044, ease: 0.0050, straightLeg: true)
    }

    /// Shorts: mid-thigh, with a slightly open leg.
    static func shortsMesh(shape: BodyShape) -> MannequinMesh {
        GarmentFit.pants(shape, waistY: 0.600, hemY: 0.360, ease: 0.0050, straightLeg: false, hemFlare: 0.0040)
    }

    /// Capris: mid-calf, close fit.
    static func caprisMesh(shape: BodyShape) -> MannequinMesh {
        GarmentFit.pants(shape, waistY: 0.638, hemY: 0.170, ease: 0.0035, straightLeg: false)
    }

    /// Leggings: skin tight, full length, high waist.
    static func leggingsMesh(shape: BodyShape) -> MannequinMesh {
        GarmentFit.pants(shape, waistY: 0.648, hemY: 0.040, ease: 0.0025, straightLeg: false)
    }

    // MARK: - Skirts & Dresses
    // The skirt part follows the hips, then flares out to `hemWidth` x `hemDepth` (half-sizes, times the hip scale)
    // while staying inside the hanging hands and outside the legs.

    /// Skirt: A-line from the waist to mid-thigh.
    static func skirtMesh(shape: BodyShape) -> MannequinMesh {
        let rings = GarmentFit.skirtRings(
            shape, hemY: 0.360, hemWidth: 0.135 * shape.hips, hemDepth: 0.090 * shape.hips, ease: 0.0050
        ) + GarmentFit.torsoRings(shape, from: GarmentFit.hipY, to: 0.645, ease: 0.0050)
        return MannequinGeometry.loft(rings, sides: 40, steps: 1, caps: (start: 0.006, end: 0.006))
    }

    /// Dress: covered shoulders, short sleeves, knee length.
    static func dressMesh(shape: BodyShape) -> MannequinMesh {
        var mesh = GarmentFit.dressShell(
            shape, hemY: 0.330, hemWidth: 0.132 * shape.hips, hemDepth: 0.088 * shape.hips, ease: 0.0065
        )
        for side: Float in [-1, 1] {
            mesh.append(GarmentFit.sleeve(shape, side: side, endY: 0.705, ease: 0.0065, flare: 0.0025))
        }
        return mesh
    }

    /// Long dress: covered shoulders, elbow sleeves, floor length.
    static func longDressMesh(shape: BodyShape) -> MannequinMesh {
        var mesh = GarmentFit.dressShell(
            shape, hemY: 0.070, hemWidth: 0.145 * shape.hips, hemDepth: 0.098 * shape.hips, ease: 0.0065
        )
        for side: Float in [-1, 1] {
            mesh.append(GarmentFit.sleeve(shape, side: side, endY: 0.675, ease: 0.0065, flare: 0.0025))
        }
        return mesh
    }

    // MARK: - Accessories & Shoes

    /// Beanie: a knit cap over short hair, with a folded cuff above the eyebrows.
    /// The face is not passed in, so each ring is sized to enclose the head plus short hair for every face preset
    /// of the avatar's gender (male body presets are the ones with neck > 1), plus the knit thickness.
    static func beanieMesh(shape: BodyShape) -> MannequinMesh {
        let gender: AvatarGender = shape.neck > 1.05 ? .male : .female
        let knit: Float = 0.0025
        let heights: [Float] = [0.958, 0.966, 0.976, 0.986, 0.995, 1.002]
        var shell: [SIMD3<Float>] = []
        for face in FaceShape.presets(for: gender) {
            for column in 0..<48 {
                for row in 0...24 {
                    let theta = Float(column) / 48 * 2 * .pi, phi = Float(row) / 24 * .pi * 0.5
                    // Short-hair volume as in Mannequin.hairHeight: 0.006 at the sides, up to 0.010 on the crown.
                    let hair = 0.006 + 0.004 * max(cos(phi), 0)
                    shell.append(Mannequin.headPoint(face, theta: theta, phi: phi, inflate: hair))
                }
            }
        }
        let centerZ = Mannequin.headCenter.z
        let keys = heights.enumerated().map { index, height -> LoftRing in
            let band = shell.filter { abs($0.y - height) < 0.004 }
            let maxX = band.map { abs($0.x) }.max() ?? 0.03
            let maxZ = band.map { abs($0.z - centerZ) }.max() ?? 0.03
            let scale = band.map { point -> Float in
                let across = point.x / maxX, along = (point.z - centerZ) / maxZ
                return (across * across + along * along).squareRoot()
            }.max() ?? 1
            let cuff: Float = index < 2 ? 0.0015 : 0  // the folded brim sits a little thicker
            return LoftRing([0, height, centerZ], width: maxX * scale + knit + cuff, depth: maxZ * scale + knit + cuff)
        }
        let crownTop = (shell.map(\.y).max() ?? 1.01) + knit + 0.002  // a slight slouch over the crown
        return MannequinGeometry.loft(keys, sides: 32, caps: (start: 0.004, end: max(crownTop - 1.002, 0.004)))
    }

    /// Sneakers: low-top athletic shoes.
    static func sneakersMesh(shape: BodyShape) -> MannequinMesh {
        var mesh = MannequinMesh()
        for side: Float in [-1, 1] {
            mesh.append(shoe(shape, side: side))
        }
        return mesh
    }

    /// Boots: shoe plus a shaft over the ankle and lower shin.
    static func bootsMesh(shape: BodyShape) -> MannequinMesh {
        var mesh = MannequinMesh()
        for side: Float in [-1, 1] {
            let footX = side * 0.045
            let shaftKeys = [
                LoftRing([footX, 0.125, -0.001], width: 0.026 * shape.limbs, depth: 0.027 * shape.limbs),
                LoftRing([footX, 0.068, -0.003], width: 0.023 * shape.limbs, depth: 0.025 * shape.limbs),
                LoftRing([footX, 0.036, -0.005], width: 0.025 * shape.limbs, depth: 0.026 * shape.limbs)
            ]
            mesh.append(MannequinGeometry.loft(shaftKeys, sides: 20, caps: (start: 0.010, end: 0.008)))
            mesh.append(shoe(shape, side: side))
        }
        return mesh
    }

    private static func shoe(_ shape: BodyShape, side: Float) -> MannequinMesh {
        let size = (1 + shape.limbs) / 2
        let footX = side * 0.045
        let keys = [
            LoftRing([footX, 0.024, -0.026], width: 0.022 * size, depth: 0.024),
            LoftRing([footX, 0.021, 0.014], width: 0.029 * size, depth: 0.020),
            LoftRing([footX * 1.02, 0.015, 0.060], width: 0.032 * size, depth: 0.016),
            LoftRing([footX * 1.05, 0.011, 0.090], width: 0.026 * size, depth: 0.013)
        ]
        return MannequinGeometry.loft(keys, sides: 20, caps: (start: 0.014, end: 0.014), reference: [0, 1, 0])
    }
}

// MARK: - Fitting helpers

/// Builds garment pieces as offsets of the body's own surface.
private enum GarmentFit {
    /// Height of the widest hip ring. Below it, tops and skirts fall straight instead of tucking into the crotch.
    static let hipY: Float = 0.535
    private static let midThighY: Float = 0.38
    private static let calfY: Float = 0.21

    // MARK: Torso garments

    /// Torso rings from `low` to `high`, pushed out by `ease`. Around the hips the rings also enclose the tops
    /// of the thighs, which stick out past the torso on narrow-hipped bodies (the male presets).
    static func torsoRings(_ shape: BodyShape, from low: Float, to high: Float, ease: Float) -> [LoftRing] {
        BodyReference.slice(BodyReference.dense(BodyReference.torso(shape)), from: low, to: high).map { ring in
            let grown = eased(ring, ease)
            return grown.center.y < 0.60 ? covering(grown, shape: shape, ease: ease) : grown
        }
    }

    /// The torso part of a top. Without `topY` it closes over the shoulders like the body does,
    /// so the neck comes out through a natural crew neckline.
    static func torsoShell(_ shape: BodyShape, hemY: Float, topY: Float? = nil, ease: Float) -> MannequinMesh {
        var rings: [LoftRing] = []
        if hemY < hipY {
            rings += drapeRings(shape, from: hemY, ease: ease)
        }
        let upper = torsoRings(shape, from: max(hemY, hipY), to: topY ?? 1, ease: ease)
        // A tank top ends where the neck starts, so only garments that close over the shoulders need this.
        rings += topY == nil ? coveringNeckBase(upper, shape: shape, ease: ease) : upper
        let topCap = topY == nil ? BodyReference.torsoCaps.end + ease : 0.004
        return MannequinGeometry.loft(rings, sides: 40, steps: 1, caps: (start: 0.006, end: topCap))
    }

    /// Thick necks (the male presets) slope out behind the shoulders; push the back of the rings out to cover
    /// that slope without pulling the front in, so the back neckline does not flicker against the skin.
    /// The push fades out over a few centimetres so it does not leave a crease across the back.
    private static func coveringNeckBase(_ rings: [LoftRing], shape: BodyShape, ease: Float) -> [LoftRing] {
        let neck = BodyReference.withCaps(BodyReference.dense(BodyReference.neck(shape)), BodyReference.neckCaps)
        let needed = rings.map { ring -> Float in
            guard let section = BodyReference.ring(atY: ring.center.y, in: neck) else { return 0 }
            let grown = eased(section, ease)
            var back = ring.center.z - ring.depth
            for corner in 0..<32 {
                let angle = Float(corner) / 32 * 2 * .pi
                let across = (grown.center.x + grown.width * cos(angle)) / ring.width
                let pointZ = grown.center.z + grown.depth * sin(angle)
                guard abs(across) < 0.95, pointZ < ring.center.z else { continue }
                back = min(back, ring.center.z - (ring.center.z - pointZ) / (1 - across * across).squareRoot())
            }
            return (ring.center.z - ring.depth) - back
        }
        return rings.map { ring in
            let extra = zip(rings, needed)
                .map { other, need in need - abs(other.center.y - ring.center.y) * 0.35 }
                .max() ?? 0
            guard extra > 0 else { return ring }
            // Move the centre back by a third and deepen by two thirds: the back reaches the neck base and
            // the front never sinks toward the skin, even off the centre line.
            return LoftRing(ring.center - [0, 0, extra / 3], width: ring.width, depth: ring.depth + extra * 2 / 3)
        }
    }

    /// A top or dress torso with a flared skirt below the hips.
    static func dressShell(
        _ shape: BodyShape, hemY: Float, hemWidth: Float, hemDepth: Float, ease: Float
    ) -> MannequinMesh {
        let rings = skirtRings(shape, hemY: hemY, hemWidth: hemWidth, hemDepth: hemDepth, ease: ease)
            + coveringNeckBase(torsoRings(shape, from: hipY, to: 1, ease: ease), shape: shape, ease: ease)
        let caps = (start: Float(0.006), end: BodyReference.torsoCaps.end + ease)
        return MannequinGeometry.loft(rings, sides: 40, steps: 1, caps: caps)
    }

    /// Straight drape from `hemY` up to just below the hips: as wide as the hips, or wider where the thighs need it.
    private static func drapeRings(_ shape: BodyShape, from hemY: Float, ease: Float) -> [LoftRing] {
        let hip = eased(hipRing(shape), ease)
        return straightened(stride(from: hemY, to: hipY - 0.006, by: 0.012).map { height in
            let design = LoftRing([hip.center.x, height, hip.center.z], width: hip.width, depth: hip.depth)
            return covering(design, shape: shape, ease: ease)
        })
    }

    /// Fabric hanging from the hips never narrows on the way down: each ring is at least as big as the one above.
    private static func straightened(_ ascending: [LoftRing]) -> [LoftRing] {
        var rings = ascending
        for index in rings.indices.reversed().dropFirst() {
            rings[index].width = max(rings[index].width, rings[index + 1].width)
            rings[index].depth = max(rings[index].depth, rings[index + 1].depth)
        }
        return rings
    }

    /// A-line rings from the hem up to just below the hips, flaring smoothly (more toward the hem).
    static func skirtRings(
        _ shape: BodyShape, hemY: Float, hemWidth: Float, hemDepth: Float, ease: Float
    ) -> [LoftRing] {
        let hip = eased(hipRing(shape), ease)
        let handLimit = BodyReference.handInnerX(shape) - 0.003
        return straightened(stride(from: hemY, to: hipY - 0.006, by: 0.012).map { height in
            let amount = (hipY - height) / (hipY - hemY)
            let flare = amount * amount
            var width = hip.width + (max(hemWidth, hip.width) - hip.width) * flare
            let depth = hip.depth + (max(hemDepth, hip.depth) - hip.depth) * flare
            // Keep the skirt inside the hanging hands (fingertips end near y = 0.40), then let it open
            // out at a steady slope below them instead of jumping wide.
            width = softMin(width, handLimit + max(0, 0.405 - height) * 0.45, smoothing: 0.006)
            let design = LoftRing([0, height, hip.center.z], width: width, depth: depth)
            return covering(design, shape: shape, ease: ease)
        })
    }

    /// A rounded minimum, so a clamped outline bends instead of creasing.
    private static func softMin(_ first: Float, _ second: Float, smoothing: Float) -> Float {
        let blend = min(max(0.5 + (second - first) / (2 * smoothing), 0), 1)
        return second + (first - second) * blend - smoothing * blend * (1 - blend)
    }

    /// Scales `design` up (never down) until it encloses the torso and both legs at its height, plus ease.
    private static func covering(_ design: LoftRing, shape: BodyShape, ease: Float) -> LoftRing {
        let height = design.center.y
        let torso = BodyReference.ring(atY: height, in: BodyReference.dense(BodyReference.torso(shape)))
        var sections = [torso.map { eased($0, ease) }]
        for side: Float in [-1, 1] {
            let leg = BodyReference.withCaps(
                BodyReference.dense(BodyReference.leg(shape, side: side)), BodyReference.legCaps
            )
            // The thigh tops are tilted, which the rings here only approximate, so leave them a little extra room.
            sections.append(BodyReference.ring(atY: height, in: leg).map { eased($0, ease + 0.0025) })
        }
        var scale: Float = 1
        for grown in sections.compactMap({ $0 }) {
            for corner in 0..<32 {
                let angle = Float(corner) / 32 * 2 * .pi
                let across = (grown.center.x + grown.width * cos(angle)) / design.width
                let along = (grown.center.z + grown.depth * sin(angle) - design.center.z) / design.depth
                scale = max(scale, (across * across + along * along).squareRoot())
            }
        }
        return LoftRing(design.center, width: design.width * scale, depth: design.depth * scale)
    }

    private static func hipRing(_ shape: BodyShape) -> LoftRing {
        BodyReference.ring(atY: hipY, in: BodyReference.dense(BodyReference.torso(shape)))
            ?? LoftRing([0, hipY, -0.006], width: 0.093 * shape.hips, depth: 0.058 * shape.hips)
    }

    /// The eased torso ring at a height (used to place pockets on a garment's front).
    static func frontRing(_ shape: BodyShape, atY height: Float, ease: Float) -> LoftRing {
        let ring = BodyReference.ring(atY: height, in: BodyReference.dense(BodyReference.torso(shape)))
        return eased(ring ?? LoftRing([0, height, 0], width: 0.07, depth: 0.047), ease)
    }

    /// The z of the back of the torso at a height.
    static func backZ(_ shape: BodyShape, atY height: Float) -> Float {
        let ring = frontRing(shape, atY: height, ease: 0)
        return ring.center.z - ring.depth
    }

    static func neckHalfWidth(_ shape: BodyShape, atY height: Float) -> Float {
        BodyReference.ring(atY: height, in: BodyReference.dense(BodyReference.neck(shape)))?.width ?? 0.03
    }

    // MARK: Sleeves

    /// A sleeve that follows the arm from the shoulder cap down to `endY`, opening by `flare` at the cuff.
    static func sleeve(_ shape: BodyShape, side: Float, endY: Float, ease: Float, flare: Float) -> MannequinMesh {
        var rings = BodyReference.slice(BodyReference.dense(BodyReference.arm(shape, side: side)), from: endY, to: 1)
            .map { eased($0, ease) }
        if let cuff = rings.indices.last {
            rings[cuff] = eased(rings[cuff], flare)
        }
        let caps = (start: BodyReference.armCaps(shape).start + ease, end: Float(0.006))
        return MannequinGeometry.loft(rings, sides: 24, steps: 1, caps: caps)
    }

    // MARK: Bottoms

    /// Seat over the hips up to `waistY`, and two legs down to `hemY`.
    static func pants(
        _ shape: BodyShape, waistY: Float, hemY: Float, ease: Float, straightLeg: Bool, hemFlare: Float = 0.0015
    ) -> MannequinMesh {
        let seat = BodyReference.slice(BodyReference.dense(BodyReference.torso(shape)), from: 0, to: waistY)
            .map { eased($0, ease) }
        var mesh = MannequinGeometry.loft(
            seat, sides: 40, steps: 1, caps: (start: BodyReference.torsoCaps.start + ease, end: 0.006)
        )
        for side: Float in [-1, 1] {
            let leg = BodyReference.dense(BodyReference.leg(shape, side: side))
            var rings = BodyReference.slice(leg, from: hemY, to: 1).map { eased($0, ease) }
            if straightLeg, let calf = BodyReference.ring(atY: calfY, in: leg).map({ eased($0, ease) }) {
                // Below mid-thigh the fabric never gets narrower than the calf, so it falls straight past the knee.
                for index in rings.indices where rings[index].center.y < midThighY {
                    rings[index].width = max(rings[index].width, calf.width)
                    rings[index].depth = max(rings[index].depth, calf.depth)
                }
            }
            if let hem = rings.indices.last {
                rings[hem] = eased(rings[hem], hemFlare)
            }
            let caps = (start: BodyReference.legCaps.start + ease, end: Float(0.006))
            mesh.append(MannequinGeometry.loft(rings, sides: 28, steps: 1, caps: caps))
        }
        return mesh
    }

    // MARK: Straps and swimwear

    /// A flat strap running over the top of the shoulder at `atX`, from the chest to the upper back,
    /// lying on whatever is highest there (torso, neck base or arm).
    static func shoulderStrap(_ shape: BodyShape, atX strapX: Float, ease: Float, halfWidth: Float) -> MannequinMesh {
        let thickness: Float = 0.0025
        let parts = BodyReference.upperBodyParts(shape)
        let center = SIMD3<Float>(strapX, 0.795, 0)
        let rings = stride(from: Float(-25), through: 205, by: 7.5).map { degrees -> LoftRing in
            let angle = degrees * .pi / 180
            let direction = SIMD3<Float>(0, sin(angle), cos(angle))
            let reach = BodyReference.surfaceDistance(from: center, along: direction, parts: parts)
            return LoftRing(center + direction * (reach + ease + thickness), width: thickness, depth: halfWidth)
        }
        return MannequinGeometry.loft(
            rings, sides: 12, steps: 2, caps: (start: 0.003, end: 0.003), reference: [1, 0, 0]
        )
    }

    /// A triangle cup lying on the chest. Returns the mesh and the apex where the halter starts.
    static func cup(_ shape: BodyShape, side: Float, ease: Float) -> (mesh: MannequinMesh, apex: SIMD3<Float>) {
        let torso = BodyReference.dense(BodyReference.torso(shape))
        let rows = 10, columns = 10
        let bottom: Float = 0.700, top: Float = 0.772
        var mesh = MannequinMesh()
        for row in 0...rows {
            let rise = Float(row) / Float(rows)
            let height = bottom + (top - bottom) * rise
            let middle = side * (0.044 - 0.010 * rise) * shape.bust
            let halfSpan = (0.026 * (1 - rise) + 0.004 * rise) * shape.bust
            for column in 0...columns {
                let across = Float(column) / Float(columns) * 2 - 1
                let bulge = 0.0025 * (1 - across * across) * sin(.pi * min(rise * 1.3, 1))
                let pointX = middle + halfSpan * across
                let surfaceZ = BodyReference.frontZ(torso, atX: pointX, y: height)
                mesh.positions.append([pointX, height, surfaceZ + ease + bulge])
            }
        }
        for row in 0..<rows {
            for column in 0..<columns {
                let here = UInt32(row * (columns + 1) + column), above = here + UInt32(columns + 1)
                mesh.indices += [here, here + 1, above, here + 1, above + 1, above]
            }
        }
        mesh.normals = faceNormals(mesh)
        let apex = mesh.positions[rows * (columns + 1) + columns / 2]
        return (mesh, apex)
    }

    /// A thin strap from the cup apex up the chest into the halter tie at the side of the neck.
    /// Each point sits on the real front surface (torso, neck base or neck) pushed out along that surface's
    /// normal, so it keeps the same gap over the sloping upper chest instead of sinking into it.
    static func halterStrap(_ shape: BodyShape, from apex: SIMD3<Float>, side: Float, ease: Float) -> MannequinMesh {
        let skin = BodyReference.upperBodySkin(shape)
        let thickness: Float = 0.002
        let endY: Float = 0.846                    // middle of the neck tie, so the strap runs into it
        let endX = side * (neckHalfWidth(shape, atY: endY) * 0.85)
        let steps = 24
        let rings = (0...steps).map { step -> LoftRing in
            let along = Float(step) / Float(steps)
            let pointX = apex.x + (endX - apex.x) * along
            let height = apex.y + (endY - apex.y) * along
            let surface = BodyReference.frontSurface(atX: pointX, y: height, skin: skin)
            let normal = BodyReference.frontNormal(atX: pointX, y: height, skin: skin)
            return LoftRing(surface + normal * (ease + thickness), width: 0.0045, depth: thickness)
        }
        return MannequinGeometry.loft(rings, sides: 12, steps: 2, caps: (start: 0.003, end: 0.003))
    }

    /// A narrow band around the neck at a height (the halter tie).
    static func neckBand(_ shape: BodyShape, atY height: Float, ease: Float) -> MannequinMesh {
        let neck = BodyReference.dense(BodyReference.neck(shape))
        let keys = [height - 0.005, height + 0.005].compactMap { BodyReference.ring(atY: $0, in: neck) }
            .map { eased($0, ease + 0.002) }
        return MannequinGeometry.loft(keys, sides: 24, steps: 1, caps: (start: 0.002, end: 0.002))
    }

    // MARK: Small helpers

    static func eased(_ ring: LoftRing, _ ease: Float) -> LoftRing {
        LoftRing(ring.center, width: ring.width + ease, depth: ring.depth + ease)
    }

    private static func faceNormals(_ mesh: MannequinMesh) -> [SIMD3<Float>] {
        var normals = [SIMD3<Float>](repeating: .zero, count: mesh.positions.count)
        for start in stride(from: 0, to: mesh.indices.count - 2, by: 3) {
            let corners = (0..<3).map { Int(mesh.indices[start + $0]) }
            let edgeA = mesh.positions[corners[1]] - mesh.positions[corners[0]]
            let edgeB = mesh.positions[corners[2]] - mesh.positions[corners[0]]
            let face = SIMD3<Float>(
                edgeA.y * edgeB.z - edgeA.z * edgeB.y,
                edgeA.z * edgeB.x - edgeA.x * edgeB.z,
                edgeA.x * edgeB.y - edgeA.y * edgeB.x
            )
            for corner in corners { normals[corner] += face }
        }
        return normals.map { normal in
            let length = (normal * normal).sum().squareRoot()
            return length > 1e-12 ? normal / length : SIMD3(0, 0, 1)
        }
    }
}

// MARK: - Body reference

/// Copies of the key rings in Mannequin.swift, where they are private. Keep these in sync with
/// Mannequin.torso / neck / arm / leg / wristX / hand: every garment is built from them.
private enum BodyReference {
    static let torsoCaps: (start: Float, end: Float) = (0.015, 0.022)
    static let neckCaps: (start: Float, end: Float) = (0.01, 0.012)
    static let legCaps: (start: Float, end: Float) = (0.03, 0.014)
    static func armCaps(_ shape: BodyShape) -> (start: Float, end: Float) { (0.024 * shape.limbs, 0.01) }

    static func torso(_ shape: BodyShape) -> [LoftRing] {
        let lowerWaist = (shape.hips + shape.waist) / 2
        let upperWaist = (shape.waist + shape.bust) / 2
        return [
            LoftRing([0, 0.455, -0.004], width: 0.060 * shape.hips, depth: 0.044 * shape.hips),
            LoftRing([0, 0.5, -0.007], width: 0.091 * shape.hips, depth: 0.056 * shape.hips),
            LoftRing([0, 0.535, -0.006], width: 0.093 * shape.hips, depth: 0.058 * shape.hips),
            LoftRing([0, 0.585, -0.003], width: 0.077 * lowerWaist, depth: 0.050 * lowerWaist),
            LoftRing([0, 0.635, 0], width: 0.065 * shape.waist, depth: 0.045 * shape.waist),
            LoftRing([0, 0.69, 0.003], width: 0.076 * upperWaist, depth: 0.050 * upperWaist),
            LoftRing([0, 0.735, 0.006], width: 0.085 * shape.bust, depth: 0.056 * shape.bust),
            LoftRing([0, 0.78, 0.002], width: 0.094 * shape.shoulders, depth: 0.050 * shape.bust),
            LoftRing([0, 0.81, -0.003], width: 0.096 * shape.shoulders, depth: 0.042 * shape.bust)
        ]
    }

    static func neck(_ shape: BodyShape) -> [LoftRing] {
        let scale = (1 + shape.limbs) / 2 * shape.neck
        return [
            LoftRing([0, 0.8, -0.01], width: 0.046 * scale, depth: 0.034 * scale),
            LoftRing([0, 0.83, -0.007], width: 0.029 * scale, depth: 0.027 * scale),
            LoftRing([0, 0.86, -0.004], width: 0.023 * scale, depth: 0.025 * scale),
            LoftRing([0, 0.89, -0.001], width: 0.021 * scale, depth: 0.023 * scale)
        ]
    }

    static func wristX(_ shape: BodyShape) -> Float {
        0.1 * shape.shoulders + 0.025 + max(0, shape.hips - 1) * 0.06
    }

    /// The inner edge of the palm, which hangs beside the hips.
    static func handInnerX(_ shape: BodyShape) -> Float {
        wristX(shape) + 0.002 - 0.017 * (1 + shape.limbs) / 2
    }

    static func arm(_ shape: BodyShape, side: Float) -> [LoftRing] {
        let limbs = shape.limbs
        let shoulderX = 0.1 * shape.shoulders
        return [
            LoftRing([side * shoulderX, 0.8, -0.004], width: 0.026 * limbs, depth: 0.028 * limbs),
            LoftRing([side * (shoulderX + 0.008), 0.72, -0.006], width: 0.022 * limbs, depth: 0.024 * limbs),
            LoftRing([side * (shoulderX + 0.015), 0.635, -0.01], width: 0.018 * limbs, depth: 0.019 * limbs),
            LoftRing([side * (shoulderX + 0.019), 0.585, -0.006], width: 0.019 * limbs, depth: 0.019 * limbs),
            LoftRing([side * wristX(shape), 0.505, 0], width: 0.0135 * limbs, depth: 0.012 * limbs)
        ]
    }

    static func leg(_ shape: BodyShape, side: Float) -> [LoftRing] {
        let thigh = (shape.hips + shape.limbs) / 2
        let limbs = shape.limbs
        let hipX = max(0.05 * shape.hips, 0.046 * thigh + 0.003)
        return [
            LoftRing([side * hipX, 0.53, -0.005], width: 0.040 * thigh, depth: 0.044 * thigh),
            LoftRing([side * hipX, 0.47, -0.003], width: 0.048 * thigh, depth: 0.050 * thigh),
            LoftRing([side * hipX * 0.96, 0.38, 0], width: 0.040 * thigh, depth: 0.042 * thigh),
            LoftRing([side * 0.044, 0.285, 0.002], width: 0.026 * limbs, depth: 0.028 * limbs),
            LoftRing([side * 0.044, 0.21, -0.005], width: 0.030 * limbs, depth: 0.033 * limbs),
            LoftRing([side * 0.044, 0.12, -0.002], width: 0.021 * limbs, depth: 0.022 * limbs),
            LoftRing([side * 0.045, 0.06, -0.004], width: 0.016 * limbs, depth: 0.017 * limbs),
            LoftRing([side * 0.045, 0.038, -0.006], width: 0.016 * limbs, depth: 0.018 * limbs)
        ]
    }

    /// Torso, neck and both arms with their rounded ends, for surface lookups.
    static func upperBodyParts(_ shape: BodyShape) -> [[LoftRing]] {
        var parts = [withCaps(dense(torso(shape)), torsoCaps), withCaps(dense(neck(shape)), neckCaps)]
        for side: Float in [-1, 1] {
            parts.append(withCaps(dense(arm(shape, side: side)), armCaps(shape)))
        }
        return parts
    }

    // MARK: Ring math (mirrors MannequinGeometry.loft)

    /// The rings MannequinGeometry.loft actually draws between `keys` (Catmull-Rom, 4 steps per span).
    static func dense(_ keys: [LoftRing], steps: Int = 4) -> [LoftRing] {
        guard keys.count > 1 else { return keys }
        var rings: [LoftRing] = []
        for index in 0..<(keys.count - 1) {
            let before = keys[max(index - 1, 0)], start = keys[index]
            let end = keys[index + 1], after = keys[min(index + 2, keys.count - 1)]
            for step in 0..<steps {
                let amount = Float(step) / Float(steps)
                let center = spline(before.center, start.center, end.center, after.center, amount)
                let size = spline(
                    SIMD2(before.width, before.depth), SIMD2(start.width, start.depth),
                    SIMD2(end.width, end.depth), SIMD2(after.width, after.depth), amount
                )
                rings.append(LoftRing(center, width: max(size.x, 0.001), depth: max(size.y, 0.001)))
            }
        }
        rings.append(keys[keys.count - 1])
        return rings
    }

    /// Adds the rounded ends the loft puts on each part (approximated as horizontal rings).
    static func withCaps(_ rings: [LoftRing], _ caps: (start: Float, end: Float)) -> [LoftRing] {
        guard let first = rings.first, let last = rings.last, rings.count > 1 else { return rings }
        func cap(_ ring: LoftRing, toward direction: SIMD3<Float>, reach: Float) -> [LoftRing] {
            (1...4).map { step in
                let angle = Float(step) / 4 * .pi / 2
                return LoftRing(
                    ring.center + direction * (sin(angle) * reach),
                    width: max(ring.width * cos(angle), 0.0005),
                    depth: max(ring.depth * cos(angle), 0.0005)
                )
            }
        }
        let startDirection = normalized(first.center - rings[1].center)
        let endDirection = normalized(last.center - rings[rings.count - 2].center)
        return cap(first, toward: startDirection, reach: caps.start).reversed() + rings
            + cap(last, toward: endDirection, reach: caps.end)
    }

    /// Rings whose height lies in `low...high`, in their original order, with exact rings added at the cuts.
    static func slice(_ rings: [LoftRing], from low: Float, to high: Float) -> [LoftRing] {
        var result: [LoftRing] = []
        for index in rings.indices {
            let ring = rings[index]
            if index > 0 {
                let previous = rings[index - 1]
                let span = ring.center.y - previous.center.y
                let cuts = [low, high]
                    .filter { span != 0 && ($0 - previous.center.y) * ($0 - ring.center.y) < 0 }
                    .map { ($0 - previous.center.y) / span }
                    .sorted()
                result += cuts.map { mix(previous, ring, $0) }
            }
            if ring.center.y >= low && ring.center.y <= high { result.append(ring) }
        }
        // Drop rings that crowd a neighbour, keeping the exact cut rings at both ends.
        var tidy: [LoftRing] = []
        for (index, ring) in result.enumerated() {
            if let kept = tidy.last, abs(kept.center.y - ring.center.y) < 0.0015 {
                if index == result.count - 1 { tidy[tidy.count - 1] = ring }
                continue
            }
            tidy.append(ring)
        }
        return tidy
    }

    /// The ring at a height, interpolated between neighbours; nil outside the part.
    static func ring(atY height: Float, in rings: [LoftRing]) -> LoftRing? {
        for index in 1..<max(rings.count, 1) {
            let lower = rings[index - 1], upper = rings[index]
            let span = upper.center.y - lower.center.y
            if span != 0 && (height - lower.center.y) * (height - upper.center.y) <= 0 {
                return mix(lower, upper, (height - lower.center.y) / span)
            }
        }
        return nil
    }

    /// The z of a part's front surface at (x, y), or -infinity where the part is not there.
    static func frontZ(_ rings: [LoftRing], atX pointX: Float, y height: Float) -> Float {
        guard let ring = ring(atY: height, in: rings) else { return -.infinity }
        let across = (pointX - ring.center.x) / ring.width
        guard abs(across) < 1 else { return -.infinity }
        return ring.center.z + ring.depth * (1 - across * across).squareRoot()
    }

    /// The torso, neck and arm meshes exactly as Mannequin.body builds them (same keys, sides and caps).
    static func upperBodySkin(_ shape: BodyShape) -> MannequinMesh {
        var mesh = MannequinGeometry.loft(torso(shape), sides: 40, caps: torsoCaps)
        mesh.append(MannequinGeometry.loft(neck(shape), sides: 24, caps: neckCaps))
        for side: Float in [-1, 1] {
            mesh.append(MannequinGeometry.loft(arm(shape, side: side), sides: 24, caps: armCaps(shape)))
        }
        return mesh
    }

    /// The frontmost point of `skin` at (x, y): a ray cast from in front of the body straight back.
    static func frontSurface(atX pointX: Float, y height: Float, skin: MannequinMesh) -> SIMD3<Float> {
        var best: Float = -.infinity
        for start in stride(from: 0, to: skin.indices.count - 2, by: 3) {
            let first = skin.positions[Int(skin.indices[start])]
            let second = skin.positions[Int(skin.indices[start + 1])]
            let third = skin.positions[Int(skin.indices[start + 2])]
            // Barycentric test in the x-y plane, then the z of the hit.
            let denominator = (second.y - third.y) * (first.x - third.x) + (third.x - second.x) * (first.y - third.y)
            guard abs(denominator) > 1e-12 else { continue }
            let offsetX = pointX - third.x, offsetY = height - third.y
            let weightA = ((second.y - third.y) * offsetX + (third.x - second.x) * offsetY) / denominator
            let weightB = ((third.y - first.y) * offsetX + (first.x - third.x) * offsetY) / denominator
            let weightC = 1 - weightA - weightB
            guard weightA >= 0, weightB >= 0, weightC >= 0 else { continue }
            best = max(best, weightA * first.z + weightB * second.z + weightC * third.z)
        }
        return [pointX, height, best.isFinite ? best : 0]
    }

    /// The outward normal of the skin's front at (x, y), from neighbouring surface points.
    static func frontNormal(atX pointX: Float, y height: Float, skin: MannequinMesh) -> SIMD3<Float> {
        let step: Float = 0.003
        let across = frontSurface(atX: pointX + step, y: height, skin: skin)
            - frontSurface(atX: pointX - step, y: height, skin: skin)
        let upward = frontSurface(atX: pointX, y: height + step, skin: skin)
            - frontSurface(atX: pointX, y: height - step, skin: skin)
        let normal = SIMD3<Float>(
            across.y * upward.z - across.z * upward.y,
            across.z * upward.x - across.x * upward.z,
            across.x * upward.y - across.y * upward.x
        )
        return normalized(normal.z < 0 ? -normal : normal)
    }

    /// How far from `start` along `direction` until the point leaves every part.
    static func surfaceDistance(from start: SIMD3<Float>, along direction: SIMD3<Float>, parts: [[LoftRing]]) -> Float {
        var reach: Float = 0
        while reach < 0.12 && parts.contains(where: { contains($0, start + direction * reach) }) {
            reach += 0.00025
        }
        return reach
    }

    private static func contains(_ rings: [LoftRing], _ point: SIMD3<Float>) -> Bool {
        guard let ring = ring(atY: point.y, in: rings) else { return false }
        let across = (point.x - ring.center.x) / ring.width
        let along = (point.z - ring.center.z) / ring.depth
        return across * across + along * along <= 1
    }

    private static func mix(_ first: LoftRing, _ second: LoftRing, _ amount: Float) -> LoftRing {
        LoftRing(
            first.center + (second.center - first.center) * amount,
            width: first.width + (second.width - first.width) * amount,
            depth: first.depth + (second.depth - first.depth) * amount
        )
    }

    private static func normalized(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let length = (vector * vector).sum().squareRoot()
        return length > 1e-12 ? vector / length : SIMD3(0, 1, 0)
    }

    private static func spline<Vector: SIMD>(
        _ before: Vector, _ start: Vector, _ end: Vector, _ after: Vector, _ amount: Float
    ) -> Vector where Vector.Scalar == Float {
        let squared = amount * amount
        let cubed = squared * amount
        let linear = (end - before) * amount
        let quadratic = (before * 2 - start * 5 + end * 4 - after) * squared
        let cubic = (start * 3 - before - end * 3 + after) * cubed
        return (start * 2 + linear + quadratic + cubic) * 0.5
    }
}
