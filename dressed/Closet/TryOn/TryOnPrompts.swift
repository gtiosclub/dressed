import Foundation

enum TryOnPrompts {
    static func avatar() -> String {
        """
        Create one stylized 2D fashion avatar from the supplied photo.
        The person is front-facing, full body, standing in a neutral pose, with both feet visible \
        and the arms held slightly away from the torso. Use one consistent illustration style and line weight.
        Keep a simple fitted neutral base layer so later garments can be composited on top. \
        Do not design a fashion outfit. Use a transparent background. Do not add text, extra people, or extra poses.
        The canvas is portrait, 1024 wide by 1536 tall.
        """
    }

    static func garment(
        template: TryOnTemplateID,
        landmarks: TryOnLandmarks,
        category: String,
        sourceFit: TryOnSourceFit,
        hemDescription: String,
        retryNotes: [String]
    ) -> String {
        let points = landmarks.present
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \(format($0.value.x)), \(format($0.value.y))" }
            .joined(separator: "; ")
        let landmarkLine = points.isEmpty
            ? "No avatar landmarks were detected. Place the garment in a natural standing position on the canvas."
            : "Detected avatar landmarks, normalized with a top-left origin: \(points)."
        let wornShoulder = sourceFitShoulderLine(sourceFit)
        let bounds = sourceFit.garmentBounds
        let retry = retryNotes.isEmpty
            ? ""
            : "The previous attempt failed these checks: \(retryNotes.joined(separator: " "))"
        return """
        TASK
        Create an avatar-aligned, garment-only asset for closet try-on overlay. \
        The second image is the canonical 2D avatar (scale and pose reference only). \
        Fit this exact garment onto that avatar body so it can be composited without further scaling.

        HOW OVERLAY WORKS
        The app draws your PNG on top of the same avatar in a fixed 1024×1536 portrait canvas. \
        Shoulder seams must line up with the avatar's leftShoulderJoint and rightShoulderJoint. \
        The torso hem must hit the avatar's \(sourceFit.hemLandmark) (\(hemDescription)). \
        Sleeves end at the avatar wrists. Misaligned width leaves the base layer visible at the sides.

        SOURCE GARMENT
        The first image is the source garment (cutout). Preserve its colors, pattern, print, logo, \
        stitching, seams, and construction — do not redesign the kurta, shirt, or other distinctive details. \
        Category: \(category). Template: \(template.rawValue) (\(template.displayName)). \
        \(template.promptRules)

        WORN-PHOTO PLACEMENT (from source fit metadata)
        Garment bounds on the worn photo: x \(format(bounds.x)), y \(format(bounds.y)), \
        width \(format(bounds.width)), height \(format(bounds.height)). \
        Torso hem landmark: \(sourceFit.hemLandmark) at \(format(sourceFit.hemPoint.x)), \
        \(format(sourceFit.hemPoint.y)). Shoulder anchor: \(format(sourceFit.shoulderPoint.x)), \
        \(format(sourceFit.shoulderPoint.y)). Worn-photo shoulder span: left \(format(wornShoulder.left)), \
        right \(format(wornShoulder.right)) (normalized coordinates).

        PLACEMENT ON AVATAR
        \(landmarkLine)
        Output shoulder width must match the avatar shoulder joint span (not narrower). \
        Torso fabric spans shoulder-to-shoulder; do not leave gaps where the tank top shows at the sides. \
        Place the torso hem at the avatar \(sourceFit.hemLandmark) level (\(hemDescription)). \
        Extend sleeves along the avatar arms to the wrists.

        OUTPUT
        Garment-only on a transparent 1024×1536 PNG. No avatar face, skin, hair, hands, legs, or background. \
        The neck hole and both sleeve cuffs must be fully transparent holes — wrists and hands are never part \
        of the garment bitmap. Keep the torso shoulder line below the chin; do not scale fabric to cover the \
        head. Keep neck openings, kurta side gaps, and layering gaps transparent. If a third image is included, \
        use it only as a body silhouette for alignment — do not paint it into the garment.

        DO NOT
        Return a full person wearing clothes or a solid fabric rectangle over the figure. Do not paint hands, \
        fingers, or face into the garment. Do not invent graphics, a back view, or closed openings. \
        Do not clip the hem, cuffs, or hood.
        \(retry)
        """
    }

    static func wearSlot(
        slot: TryOnBodySlot,
        category: ClothingCategory,
        preserveCategories: [ClothingCategory],
        preserveGarmentNames: [String],
        hemDescription: String,
        template: TryOnTemplateID,
        sourceFit: TryOnSourceFit
    ) -> String {
        let preserveSlots = preserveCategories.compactMap(TryOnBodySlot.slot(for:))
        return wearOnAvatar(
            slot: slot,
            category: category,
            preserveSlots: preserveSlots,
            preserveGarmentNames: preserveGarmentNames,
            sourceFit: sourceFit,
            hemDescription: hemDescription,
            template: template
        )
    }

    static func wearOnAvatar(
        slot: TryOnBodySlot,
        category: ClothingCategory,
        preserveSlots: [TryOnBodySlot],
        preserveGarmentNames: [String],
        sourceFit: TryOnSourceFit,
        hemDescription: String,
        template: TryOnTemplateID
    ) -> String {
        let preserveLine = preserveSlots.isEmpty
            ? "No other garments are worn yet."
            : "Keep these already-worn regions exactly as they appear in the base image: "
                + preserveSlots.map(\.displayName).joined(separator: ", ")
                + ". Do not remove, replace, or redesign them."
        let refLine = preserveGarmentNames.isEmpty
            ? ""
            : "Reference thumbnails show: \(preserveGarmentNames.joined(separator: ", ")). Match their colors and silhouette."
        let bounds = sourceFit.garmentBounds
        return """
        TASK
        Edit the base avatar image so the person is WEARING the new \(slot.displayName) garment (\(category.rawValue)), \
        styled and fitted like in the worn source photo — not a flat overlay on top of the body.

        BASE IMAGE
        The first image is the current try-on state: canonical stylized avatar or an existing outfit composite. \
        Preserve pose, illustration style, line weight, skin, hair, face, and every region outside the changing slot.

        NEW GARMENT SOURCE
        The second image is a photo of a person wearing this exact piece. Match its fit, drape, hem, color, pattern, \
        logos, and construction. Category: \(category.rawValue). Template: \(template.displayName). \
        \(template.promptRules)
        Worn-photo bounds: x \(format(bounds.x)), y \(format(bounds.y)), width \(format(bounds.width)), \
        height \(format(bounds.height)). Hem at \(sourceFit.hemLandmark): \(hemDescription).

        LAYERING — CRITICAL
        Only repaint the \(slot.displayName) body region for the new item. \(preserveLine) \(refLine)
        Changing the \(slot.displayName) must NOT remove pants, shoes, hats, or other slots already visible on the base.

        OUTPUT
        One front-facing full-body stylized figure, same style as the canonical avatar, 1024 wide by 1536 tall, \
        transparent background, single neutral standing pose, both feet visible. No text or extra people.
        If an optional garment cutout or reference images are included, use them only for color and construction — \
        do not return garment-only layers.
        """
    }

    static func pose(_ pose: TryOnPose, referenceCount: Int) -> String {
        """
        Create one stylized full-body image of the same person wearing the same garments.
        Pose: \(pose.instruction)
        The first image is the current front outfit. The other \(max(referenceCount - 1, 0)) images are \
        garment references and are the source of truth for colors, graphics, logos, and silhouette.
        Do not redesign the clothes. Unseen sides may be approximated and must not be presented as exact. \
        Transparent background. No text. Portrait canvas, 1024 wide by 1536 tall.
        """
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private static func sourceFitShoulderLine(_ fit: TryOnSourceFit) -> (left: Double, right: Double) {
        let left = fit.landmarks.leftShoulderJoint?.x
            ?? fit.landmarks.leftShoulderEdge?.x
            ?? fit.garmentBounds.x
        let right = fit.landmarks.rightShoulderJoint?.x
            ?? fit.landmarks.rightShoulderEdge?.x
            ?? fit.garmentBounds.x + fit.garmentBounds.width
        return (min(left, right), max(left, right))
    }
}
