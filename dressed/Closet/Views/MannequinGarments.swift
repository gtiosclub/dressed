import Foundation




// Procedural 3D fashion garment preset meshes for the avatar mannequin.

// Each preset fits the mannequin body shape with accurate shoulder coverage, sleeve cuts, and hem drops.

// Framing matches Mannequin.swift: 1 unit tall, feet at y = 0, facing +z.




enum MannequinGarments {

    /// Builds the 3D mesh for any GarmentPreset.

    static func mesh(for preset: GarmentPreset, shape: BodyShape) -> MannequinMesh {

        switch preset {

        // Tops with full shoulder coverage

        case .tShirt:

            return tShirtMesh(shape: shape)

        case .hoodie:

            return hoodieMesh(shape: shape)

        case .sweater:

            return sweaterMesh(shape: shape)

        case .sweatshirt:

            return sweatshirtMesh(shape: shape)

        case .jersey:

            return jerseyMesh(shape: shape)

        case .blouse:

            return blouseMesh(shape: shape)




        // Tops with exposed shoulders / minimal coverage

        case .tankTop:

            return tankTopMesh(shape: shape)

        case .cropTop:

            return cropTopMesh(shape: shape)

        case .bikini:

            return bikiniMesh(shape: shape)




        // Bottoms

        case .jeans:

            return jeansMesh(shape: shape)

        case .pants:

            return trousersMesh(shape: shape)

        case .shorts:

            return shortsMesh(shape: shape)

        case .capris:

            return caprisMesh(shape: shape)

        case .leggings:

            return leggingsMesh(shape: shape)




        // One-piece & Skirts

        case .skirt:

            return skirtMesh(shape: shape)

        case .dress:

            return dressMesh(shape: shape)

        case .longDress:

            return longDressMesh(shape: shape)




        // Accessories & Shoes

        case .beanie:

            return beanieMesh(shape: shape)

        case .sneakers:

            return sneakersMesh(shape: shape)

        case .boots:

            return bootsMesh(shape: shape)

        }

    }




    /// Backwards-compatible overload for ClothingCategory.

    static func mesh(

        for category: ClothingCategory,

        shape: BodyShape,

        proportions: GarmentProportions = GarmentProportions()

    ) -> MannequinMesh {

        switch category {

        case .tops:

            return tShirtMesh(shape: shape)

        case .pants:

            return jeansMesh(shape: shape)

        case .skirts:

            return skirtMesh(shape: shape)

        case .dresses:

            return dressMesh(shape: shape)

        case .outerwear:

            return hoodieMesh(shape: shape)

        case .shoes:

            return sneakersMesh(shape: shape)

        case .accessories:

            return beanieMesh(shape: shape)

        case .other:

            return tShirtMesh(shape: shape)

        }

    }




    // MARK: - 1. T-Shirt (Full Shoulder Coverage + Short Sleeves)




    static func tShirtMesh(shape: BodyShape) -> MannequinMesh {
        // Hem drops below the pants waistband so the shirt covers the pants.
        var mesh = coveredTorso(shape: shape, dropY: 0.520, inflate: 1.10, collarY: 0.838)
        for side: Float in [-1, 1] {
            mesh.append(shoulderAndSleeve(shape: shape, side: side, sleeveEnd: 0.755, inflate: 1.08))
        }
        return mesh
    }




    // MARK: - 2. Hoodie (Full Shoulder Coverage + Long Sleeves + Relaxed Fit + Hood)




    static func hoodieMesh(shape: BodyShape) -> MannequinMesh {

        var mesh = coveredTorso(shape: shape, dropY: 0.580, inflate: 1.15, collarY: 0.842)

        for side: Float in [-1, 1] {

            mesh.append(shoulderAndSleeve(shape: shape, side: side, sleeveEnd: 0.510, inflate: 1.16))

        }

        // Kangaroo pocket in front

        let pocketKeys = [

            LoftRing([0, 0.610, 0.056 * shape.bust * 1.15], width: 0.065 * shape.waist, depth: 0.012),

            LoftRing([0, 0.655, 0.052 * shape.waist * 1.15], width: 0.060 * shape.waist, depth: 0.010)

        ]

        mesh.append(MannequinGeometry.loft(pocketKeys, sides: 24, caps: (start: 0.008, end: 0.008)))




        // Hood resting draped behind neck and upper back

        let hoodKeys = [

            LoftRing([0, 0.825, -0.048], width: 0.055, depth: 0.030),

            LoftRing([0, 0.855, -0.065], width: 0.062, depth: 0.038),

            LoftRing([0, 0.880, -0.058], width: 0.058, depth: 0.035),

            LoftRing([0, 0.900, -0.040], width: 0.046, depth: 0.026)

        ]

        mesh.append(MannequinGeometry.loft(hoodKeys, sides: 24, caps: (start: 0.012, end: 0.012)))

        return mesh

    }




    // MARK: - 3. Sweater (Full Shoulder Coverage + Knitted Fit + Long Sleeves)




    static func sweaterMesh(shape: BodyShape) -> MannequinMesh {

        var mesh = coveredTorso(shape: shape, dropY: 0.590, inflate: 1.11, collarY: 0.840)

        for side: Float in [-1, 1] {

            mesh.append(shoulderAndSleeve(shape: shape, side: side, sleeveEnd: 0.512, inflate: 1.10))

        }

        return mesh

    }




    // MARK: - 4. Sweatshirt (Full Shoulder Coverage + Crew Neck + Long Sleeves)




    static func sweatshirtMesh(shape: BodyShape) -> MannequinMesh {

        var mesh = coveredTorso(shape: shape, dropY: 0.585, inflate: 1.12, collarY: 0.838)

        for side: Float in [-1, 1] {

            mesh.append(shoulderAndSleeve(shape: shape, side: side, sleeveEnd: 0.512, inflate: 1.13))

        }

        return mesh

    }




    // MARK: - 5. Jersey (Full Shoulder Coverage + Athletic Cut + Wide Sleeves)




    static func jerseyMesh(shape: BodyShape) -> MannequinMesh {

        // Extend the hem below the waistband and locally expand the lower
        // torso shell so it covers the hips and sits outside the pants.
        // Keep this adjustment limited to the torso mesh; sleeves are unchanged.
        var mesh = coveredTorso(shape: shape, dropY: 0.455, inflate: 1.18, collarY: 0.830)
        for i in mesh.positions.indices where mesh.positions[i].y <= 0.690 {
            let y = mesh.positions[i].y
            let waistFactor: Float = y <= 0.585 ? 1.16 : 1.10
            mesh.positions[i].x *= waistFactor
            mesh.positions[i].z = mesh.positions[i].z * waistFactor + 0.006
        }

        for side: Float in [-1, 1] {

            mesh.append(shoulderAndSleeve(shape: shape, side: side, sleeveEnd: 0.720, inflate: 1.12))

        }

        return mesh

    }




    // MARK: - 6. Blouse (Full Shoulder Coverage + Flowy Draped Torso)




    static func blouseMesh(shape: BodyShape) -> MannequinMesh {

        var mesh = coveredTorso(shape: shape, dropY: 0.590, inflate: 1.13, collarY: 0.840)

        for side: Float in [-1, 1] {

            mesh.append(shoulderAndSleeve(shape: shape, side: side, sleeveEnd: 0.560, inflate: 1.14))

        }

        return mesh

    }




    // MARK: - 7. Tank Top (Exposed Shoulders + Sleeveless Straps)




    static func tankTopMesh(shape: BodyShape) -> MannequinMesh {

        let lowerWaist = (shape.hips + shape.waist) / 2

        let upperWaist = (shape.waist + shape.bust) / 2

        let inflate: Float = 1.09

        let offset: Float = 0.005




        // Main torso body — runs from hem up to the armhole line

        let keys = [

            LoftRing([0, 0.620, -0.003], width: (0.077 * lowerWaist) * inflate + offset, depth: (0.050 * lowerWaist) * inflate + offset),

            LoftRing([0, 0.665, 0],      width: (0.065 * shape.waist) * inflate + offset, depth: (0.045 * shape.waist) * inflate + offset),

            LoftRing([0, 0.715, 0.003],  width: (0.076 * upperWaist)  * inflate + offset, depth: (0.050 * upperWaist)  * inflate + offset),

            LoftRing([0, 0.760, 0.006],  width: (0.082 * shape.bust)  * inflate + offset, depth: (0.054 * shape.bust)  * inflate + offset),

            LoftRing([0, 0.795, 0.002],  width: (0.080 * shape.bust)  * inflate + offset, depth: (0.050 * shape.bust)  * inflate + offset),

            LoftRing([0, 0.820, 0.000],  width: (0.072 * shape.bust)  * inflate + offset, depth: (0.046 * shape.bust)  * inflate + offset)

        ]

        var mesh = MannequinGeometry.loft(keys, sides: 36, caps: (start: 0.010, end: 0.010))




        // Left/right chest panels: fill the open gap between the top of the torso tube

        // and the strap attachment points. Each panel is a small loft strip that bridges

        // the armhole edge (outerX) up to the strap root, closing the visible hole.

        for side: Float in [-1, 1] {

            let outerX = side * (0.058 * shape.bust) * inflate

            let strapX = side * 0.042

            let panelKeys = [

                LoftRing([outerX,      0.818, 0.002], width: 0.016, depth: 0.032),

                LoftRing([outerX * 0.82, 0.832, 0.012], width: 0.014, depth: 0.026),

                LoftRing([strapX,      0.812, 0.040],  width: 0.022, depth: 0.018)

            ]

            mesh.append(MannequinGeometry.loft(panelKeys, sides: 16, caps: (start: 0.006, end: 0.006)))

        }




        // Narrow tank top straps arching over the shoulder close to the neck,

        // leaving outer shoulders & deltoids completely bare

        for side: Float in [-1, 1] {

            let strapX = side * 0.048

            let strapKeys = [

                LoftRing([strapX, 0.818, 0.042],  width: 0.016, depth: 0.013),

                LoftRing([strapX, 0.842, 0.010],  width: 0.015, depth: 0.012),

                LoftRing([strapX, 0.826, -0.036], width: 0.016, depth: 0.013)

            ]

            mesh.append(MannequinGeometry.loft(strapKeys, sides: 16, caps: (start: 0.006, end: 0.006)))

        }

        return mesh

    }




    // MARK: - 8. Crop Top (Exposed Midriff + Shoulders Covered)




    static func cropTopMesh(shape: BodyShape) -> MannequinMesh {

        var mesh = coveredTorso(shape: shape, dropY: 0.680, inflate: 1.06, collarY: 0.835)

        for side: Float in [-1, 1] {

            mesh.append(shoulderAndSleeve(shape: shape, side: side, sleeveEnd: 0.740, inflate: 1.06))

        }

        return mesh

    }




    // MARK: - 9. Bikini Top (Minimal Triangle Cups & Straps, Exposed Shoulders)




    static func bikiniMesh(shape: BodyShape) -> MannequinMesh {

        var mesh = MannequinMesh()

        for side: Float in [-1, 1] {

            let cupX = side * 0.044

            let cupKeys = [

                LoftRing([cupX, 0.705, 0.050], width: 0.034, depth: 0.020),

                LoftRing([cupX, 0.740, 0.046], width: 0.028, depth: 0.017),

                LoftRing([cupX * 0.88, 0.775, 0.038], width: 0.018, depth: 0.014)

            ]

            mesh.append(MannequinGeometry.loft(cupKeys, sides: 20, caps: (start: 0.008, end: 0.006)))




            // Thin neck halter strap

            let halterKeys = [

                LoftRing([cupX * 0.82, 0.780, 0.036], width: 0.009, depth: 0.009),

                LoftRing([side * 0.032, 0.845, -0.006], width: 0.008, depth: 0.008)

            ]

            mesh.append(MannequinGeometry.loft(halterKeys, sides: 12, caps: (start: 0.004, end: 0.004)))

        }

        return mesh

    }




    // MARK: - 10. Jeans (Waistband + Full Length Denim)




    static func jeansMesh(shape: BodyShape) -> MannequinMesh {

        return pantsBase(shape: shape, ankleY: 0.042, inflate: 1.12, waistbandY: 0.638)

    }




    // MARK: - 11. Pants (Straight Trousers)




    static func trousersMesh(shape: BodyShape) -> MannequinMesh {

        return pantsBase(shape: shape, ankleY: 0.044, inflate: 1.07, waistbandY: 0.642)

    }




    // MARK: - 12. Shorts (Above-the-Knee Cut)




    static func shortsMesh(shape: BodyShape) -> MannequinMesh {
        var mesh = MannequinMesh()
        let lowerWaist = (shape.hips + shape.waist) / 2
        let thigh = (shape.hips + shape.limbs) / 2
        let inflate: Float = 1.08

        // Seat covering the hips and upper thighs
        let waistbandKeys = [
            LoftRing([0, 0.44, -0.005], width: 0.112 * shape.hips * inflate, depth: 0.072 * shape.hips * inflate),
            LoftRing([0, 0.50, -0.004], width: 0.108 * shape.hips * inflate, depth: 0.070 * shape.hips * inflate),
            LoftRing([0, 0.55, -0.003], width: 0.090 * lowerWaist * inflate, depth: 0.056 * lowerWaist * inflate),
            LoftRing([0, 0.60, 0], width: 0.068 * shape.waist * inflate, depth: 0.046 * shape.waist * inflate)
        ]
        mesh.append(MannequinGeometry.loft(waistbandKeys, sides: 32, caps: (start: 0.008, end: 0.008)))

        // Short legs that cover the upper thighs
        for side: Float in [-1, 1] {
            let hipX = max(0.046 * shape.hips, 0.042 * thigh + 0.002)
            let legKeys = [
                LoftRing([side * hipX, 0.520, -0.003], width: 0.075 * thigh, depth: 0.064 * thigh),
                LoftRing([side * hipX, 0.440, -0.002], width: 0.064 * thigh, depth: 0.058 * thigh),
                LoftRing([side * hipX * 0.95, 0.360, 0], width: 0.052 * thigh, depth: 0.048 * thigh)
            ]
            mesh.append(MannequinGeometry.loft(legKeys, sides: 24, caps: (start: 0.008, end: 0.006)))
        }
        return mesh
    }




    // MARK: - 13. Capris (Mid-Calf Cut)




    static func caprisMesh(shape: BodyShape) -> MannequinMesh {

        return pantsBase(shape: shape, ankleY: 0.170, inflate: 1.07, waistbandY: 0.638)

    }




    // MARK: - 14. Leggings (Form-Fitting Full Length)




    static func leggingsMesh(shape: BodyShape) -> MannequinMesh {

        return pantsBase(shape: shape, ankleY: 0.040, inflate: 1.04, waistbandY: 0.648)

    }




    // MARK: - 15. Skirt (Flared A-Line)




    static func skirtMesh(shape: BodyShape) -> MannequinMesh {

        let lowerWaist = (shape.hips + shape.waist) / 2

        let keys = [

            LoftRing([0, 0.36, 0.002], width: 0.135 * shape.hips, depth: 0.090 * shape.hips),

            LoftRing([0, 0.43, 0.001], width: 0.118 * shape.hips, depth: 0.078 * shape.hips),

            LoftRing([0, 0.50, -0.003], width: 0.105 * shape.hips, depth: 0.068 * shape.hips),

            LoftRing([0, 0.56, -0.005], width: 0.095 * shape.hips, depth: 0.060 * shape.hips),

            LoftRing([0, 0.60, -0.003], width: 0.080 * lowerWaist, depth: 0.052 * lowerWaist),

            LoftRing([0, 0.645, 0], width: 0.070 * shape.waist, depth: 0.048 * shape.waist)

        ]

        return MannequinGeometry.loft(keys, sides: 36, caps: (start: 0.012, end: 0.012))

    }




    // MARK: - 16. Dress (Shoulders Covered + Knee-Length)




    static func dressMesh(shape: BodyShape) -> MannequinMesh {

        let lowerWaist = (shape.hips + shape.waist) / 2

        let upperWaist = (shape.waist + shape.bust) / 2

        let keys = [

            LoftRing([0, 0.33, 0.002], width: 0.132 * shape.hips, depth: 0.088 * shape.hips),

            LoftRing([0, 0.44, -0.002], width: 0.114 * shape.hips, depth: 0.074 * shape.hips),

            LoftRing([0, 0.54, -0.005], width: 0.102 * shape.hips, depth: 0.065 * shape.hips),

            LoftRing([0, 0.59, -0.003], width: 0.084 * lowerWaist, depth: 0.055 * lowerWaist),

            LoftRing([0, 0.635, 0], width: 0.070 * shape.waist, depth: 0.048 * shape.waist),

            LoftRing([0, 0.69, 0.003], width: 0.080 * upperWaist, depth: 0.054 * upperWaist),

            LoftRing([0, 0.735, 0.006], width: 0.092 * shape.bust, depth: 0.061 * shape.bust),

            LoftRing([0, 0.78, 0.002], width: 0.106 * shape.shoulders, depth: 0.055 * shape.bust),

            LoftRing([0, 0.838, -0.003], width: 0.120 * shape.shoulders, depth: 0.049 * shape.bust)

        ]

        var mesh = MannequinGeometry.loft(keys, sides: 36, caps: (start: 0.014, end: 0.015))

        for side: Float in [-1, 1] {

            mesh.append(shoulderAndSleeve(shape: shape, side: side, sleeveEnd: 0.705, inflate: 1.08))

        }

        return mesh

    }




    // MARK: - 17. Long Dress (Shoulders Covered + Floor-Length Maxi)




    static func longDressMesh(shape: BodyShape) -> MannequinMesh {

        let lowerWaist = (shape.hips + shape.waist) / 2

        let upperWaist = (shape.waist + shape.bust) / 2

        let keys = [

            LoftRing([0, 0.07, 0.002], width: 0.145 * shape.hips, depth: 0.098 * shape.hips),

            LoftRing([0, 0.22, 0.001], width: 0.136 * shape.hips, depth: 0.090 * shape.hips),

            LoftRing([0, 0.38, 0.002], width: 0.126 * shape.hips, depth: 0.082 * shape.hips),

            LoftRing([0, 0.54, -0.005], width: 0.102 * shape.hips, depth: 0.065 * shape.hips),

            LoftRing([0, 0.59, -0.003], width: 0.084 * lowerWaist, depth: 0.055 * lowerWaist),

            LoftRing([0, 0.635, 0], width: 0.070 * shape.waist, depth: 0.048 * shape.waist),

            LoftRing([0, 0.69, 0.003], width: 0.080 * upperWaist, depth: 0.054 * upperWaist),

            LoftRing([0, 0.735, 0.006], width: 0.092 * shape.bust, depth: 0.061 * shape.bust),

            LoftRing([0, 0.78, 0.002], width: 0.106 * shape.shoulders, depth: 0.055 * shape.bust),

            LoftRing([0, 0.838, -0.003], width: 0.120 * shape.shoulders, depth: 0.049 * shape.bust)

        ]

        var mesh = MannequinGeometry.loft(keys, sides: 36, caps: (start: 0.014, end: 0.015))

        for side: Float in [-1, 1] {

            mesh.append(shoulderAndSleeve(shape: shape, side: side, sleeveEnd: 0.675, inflate: 1.09))

        }

        return mesh

    }




    // MARK: - 18. Beanie (Knitted Cap Over Head and Hair)




    static func beanieMesh(shape: BodyShape) -> MannequinMesh {

        // Raised, shorter beanie: keep the fold above the forehead and ears,
        // with a compact crown that does not descend across the face.

        let keys = [

            // Brim / fold - sits just above ears and forehead
            LoftRing([0, 0.958, -0.008], width: 0.058, depth: 0.063),
            LoftRing([0, 0.975, -0.009], width: 0.056, depth: 0.061),

            // Compact crown sitting on the head top
            LoftRing([0, 0.992, -0.010], width: 0.050, depth: 0.055),
            LoftRing([0, 1.008, -0.011], width: 0.038, depth: 0.043),
            LoftRing([0, 1.018, -0.012], width: 0.020, depth: 0.024)

        ]

        return MannequinGeometry.loft(keys, sides: 32, caps: (start: 0.008, end: 0.012))

    }




    // MARK: - 19. Sneakers (Low-Top Athletic Shoes)




    static func sneakersMesh(shape: BodyShape) -> MannequinMesh {

        var mesh = MannequinMesh()

        for side: Float in [-1, 1] {

            let size = (1 + shape.limbs) / 2

            let footX = side * 0.045

            let keys = [

                LoftRing([footX, 0.024, -0.026], width: 0.022 * size, depth: 0.024),

                LoftRing([footX, 0.021, 0.014], width: 0.029 * size, depth: 0.020),

                LoftRing([footX * 1.02, 0.015, 0.060], width: 0.032 * size, depth: 0.016),

                LoftRing([footX * 1.05, 0.011, 0.090], width: 0.026 * size, depth: 0.013)

            ]

            mesh.append(MannequinGeometry.loft(keys, sides: 20, caps: (start: 0.014, end: 0.014), reference: [0, 1, 0]))

        }

        return mesh

    }




    // MARK: - 20. Boots (Ankle & Calf Boots)




    static func bootsMesh(shape: BodyShape) -> MannequinMesh {

        var mesh = MannequinMesh()

        for side: Float in [-1, 1] {

            let size = (1 + shape.limbs) / 2

            let footX = side * 0.045

            // Boot shaft covering ankle and lower shin

            let shaftKeys = [

                LoftRing([footX, 0.125, -0.001], width: 0.026 * shape.limbs, depth: 0.027 * shape.limbs),

                LoftRing([footX, 0.068, -0.003], width: 0.023 * shape.limbs, depth: 0.025 * shape.limbs),

                LoftRing([footX, 0.036, -0.005], width: 0.025 * shape.limbs, depth: 0.026 * shape.limbs)

            ]

            mesh.append(MannequinGeometry.loft(shaftKeys, sides: 20, caps: (start: 0.010, end: 0.008)))




            let footKeys = [

                LoftRing([footX, 0.024, -0.026], width: 0.022 * size, depth: 0.024),

                LoftRing([footX, 0.021, 0.014], width: 0.029 * size, depth: 0.020),

                LoftRing([footX * 1.02, 0.015, 0.060], width: 0.032 * size, depth: 0.016),

                LoftRing([footX * 1.05, 0.011, 0.090], width: 0.026 * size, depth: 0.013)

            ]

            mesh.append(MannequinGeometry.loft(footKeys, sides: 20, caps: (start: 0.014, end: 0.014), reference: [0, 1, 0]))

        }

        return mesh

    }




    // MARK: - Shared Geometry Helpers




    /// Torso mesh with full coverage bridging from waist up over the trapezius and shoulder line.

    private static func coveredTorso(shape: BodyShape, dropY: Float, inflate: Float, collarY: Float) -> MannequinMesh {

        let lowerWaist = (shape.hips + shape.waist) / 2

        let upperWaist = (shape.waist + shape.bust) / 2

        let offset: Float = 0.0050

        // Clamp extremes so large body shapes don't blow the torso outside the mannequin

        let sh = min(shape.shoulders, 1.30)

        let bu = min(shape.bust, 1.30)




        let keys = [

            LoftRing([0, dropY, -0.003],

                     width: (0.077 * lowerWaist) * inflate + offset,

                     depth: (0.050 * lowerWaist) * inflate + offset),

            LoftRing([0, 0.635, 0],

                     width: (0.065 * shape.waist) * inflate + offset,

                     depth: (0.045 * shape.waist) * inflate + offset),

            LoftRing([0, 0.690, 0.003],

                     width: (0.076 * upperWaist) * inflate + offset,

                     depth: (0.050 * upperWaist) * inflate + offset),

            LoftRing([0, 0.735, 0.006],

                     width: (0.085 * bu) * inflate + offset,

                     depth: (0.056 * bu) * inflate + offset),

            LoftRing([0, 0.780, 0.002],

                     width: (0.102 * sh) * inflate + offset,

                     depth: (0.052 * bu) * inflate + offset),

            LoftRing([0, collarY, -0.004],

                     width: (0.116 * sh) * inflate + offset,

                     depth: (0.046 * bu) * inflate + offset)

        ]

        return MannequinGeometry.loft(keys, sides: 36, caps: (start: 0.012, end: 0.015))

    }




    /// Full shoulder cap and sleeve mesh: arches from neck over the deltoid then tracks the arm

    /// path all the way to sleeveEnd so there are no exposed gaps at the elbow or forearm.

    private static func shoulderAndSleeve(

        shape: BodyShape,

        side: Float,

        sleeveEnd: Float,

        inflate: Float

    ) -> MannequinMesh {

        let limbs = shape.limbs

        let shoulderX = 0.10 * shape.shoulders

        // Wrist lateral offset mirrors Mannequin.wristX() so long sleeves end at the correct x

        let wristLateral: Float = 0.10 * shape.shoulders + 0.025 + max(0, shape.hips - 1) * 0.06

        let offset: Float = 0.0055




        // Always-present rings: collar root → shoulder apex → deltoid cap → upper bicep

        var keys: [LoftRing] = [

            LoftRing([side * (shoulderX * 0.40), 0.835, -0.004],

                     width: (0.024 * limbs) * inflate + offset,

                     depth: (0.028 * limbs) * inflate + offset),

            LoftRing([side * (shoulderX * 0.80), 0.832, -0.004],

                     width: (0.027 * limbs) * inflate + offset,

                     depth: (0.030 * limbs) * inflate + offset),

            LoftRing([side * (shoulderX + 0.012), 0.808, -0.005],

                     width: (0.030 * limbs) * inflate + offset,

                     depth: (0.032 * limbs) * inflate + offset),

            // Upper bicep — mirrors Mannequin.arm y≈0.72

            LoftRing([side * (shoulderX + 0.009), 0.724, -0.006],

                     width: (0.027 * limbs) * inflate + offset,

                     depth: (0.029 * limbs) * inflate + offset),

        ]




        // Elbow ring — added for anything below short-sleeve length

        if sleeveEnd < 0.70 {

            keys.append(LoftRing([side * (shoulderX + 0.016), 0.636, -0.010],

                                 width: (0.025 * limbs) * inflate + offset,

                                 depth: (0.027 * limbs) * inflate + offset))

        }

        // Forearm ring — added when the sleeve reaches at least 3/4 length

        if sleeveEnd < 0.60 {

            keys.append(LoftRing([side * (shoulderX + 0.020), 0.588, -0.007],

                                 width: (0.024 * limbs) * inflate + offset,

                                 depth: (0.026 * limbs) * inflate + offset))

        }

        // Wrist approach ring — for full-length sleeves that reach the wrist

        if sleeveEnd < 0.535 {

            keys.append(LoftRing([side * (wristLateral + 0.001), 0.515, -0.004],

                                 width: (0.022 * limbs) * inflate + offset,

                                 depth: (0.023 * limbs) * inflate + offset))

        }




        // Hem ring — x follows the arm so the cuff sits at the right lateral position

        let hemX: Float = sleeveEnd >= 0.70 ? shoulderX + 0.020

                        : sleeveEnd >= 0.54 ? shoulderX + 0.022

                        : wristLateral + 0.002

        keys.append(LoftRing([side * hemX, sleeveEnd, -0.006],

                             width: (0.022 * limbs) * inflate + offset,

                             depth: (0.023 * limbs) * inflate + offset))




        return MannequinGeometry.loft(keys, sides: 24, caps: (start: 0.012, end: 0.010))

    }




    /// Helper for trousers, jeans, capris, and leggings.
    /// Seat and legs are sized to fully cover the body thighs with clearance on the outside.
    private static func pantsBase(shape: BodyShape, ankleY: Float, inflate: Float, waistbandY: Float) -> MannequinMesh {
        var mesh = MannequinMesh()
        let lowerWaist = (shape.hips + shape.waist) / 2
        let thigh = (shape.hips + shape.limbs) / 2
        let limbs = shape.limbs
        let offset: Float = 0.008

        // Seat — wide and low enough to cover the upper hips and the start of the thighs.
        let waistbandKeys = [
            LoftRing([0, 0.44, -0.005], width: 0.112 * shape.hips * inflate, depth: 0.072 * shape.hips * inflate),
            LoftRing([0, 0.50, -0.004], width: 0.108 * shape.hips * inflate, depth: 0.070 * shape.hips * inflate),
            LoftRing([0, 0.55, -0.003], width: 0.092 * lowerWaist * inflate, depth: 0.058 * lowerWaist * inflate),
            LoftRing([0, waistbandY, 0], width: 0.068 * shape.waist * inflate, depth: 0.046 * shape.waist * inflate)
        ]
        mesh.append(MannequinGeometry.loft(waistbandKeys, sides: 32, caps: (start: 0.008, end: 0.008)))

        // Legs sit over the body legs. hipX matches the body, widths are larger so the outer edge covers.
        for side: Float in [-1, 1] {
            let hipX = max(0.046 * shape.hips, 0.042 * thigh + 0.002)

            var legKeys = [
                // Top ring high and wide — outer edge well past the body thigh
                LoftRing([side * hipX, 0.530, -0.004],
                         width: (0.078 * thigh) * inflate + offset,
                         depth: (0.066 * thigh) * inflate + offset),
                LoftRing([side * hipX, 0.470, -0.003],
                         width: (0.072 * thigh) * inflate + offset,
                         depth: (0.064 * thigh) * inflate + offset),
                LoftRing([side * hipX * 0.96, 0.380, 0],
                         width: (0.054 * thigh) * inflate + offset,
                         depth: (0.048 * thigh) * inflate + offset),
                LoftRing([side * 0.044, 0.285, 0.002],
                         width: (0.030 * limbs) * inflate + offset,
                         depth: (0.032 * limbs) * inflate + offset)
            ]

            if ankleY < 0.25 {
                legKeys.append(LoftRing([side * 0.044, max(ankleY, 0.21), -0.005],
                                        width: (0.032 * limbs) * inflate + offset,
                                        depth: (0.034 * limbs) * inflate + offset))
            }
            if ankleY < 0.15 {
                legKeys.append(LoftRing([side * 0.044, max(ankleY, 0.12), -0.002],
                                        width: (0.024 * limbs) * inflate + offset,
                                        depth: (0.025 * limbs) * inflate + offset))
            }
            legKeys.append(LoftRing([side * 0.045, ankleY, -0.004],
                                    width: (0.020 * limbs) * inflate + offset,
                                    depth: (0.021 * limbs) * inflate + offset))

            mesh.append(MannequinGeometry.loft(legKeys, sides: 24, caps: (start: 0.010, end: 0.008)))
        }

        return mesh
    }

}
