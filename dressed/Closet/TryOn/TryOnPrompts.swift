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
        retryNotes: [String]
    ) -> String {
        let points = landmarks.present
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \(format($0.value.x)), \(format($0.value.y))" }
            .joined(separator: "; ")
        let landmarkLine = points.isEmpty
            ? "No avatar landmarks were detected. Place the garment in a natural standing position on the canvas."
            : "Detected avatar landmarks, normalized with a top-left origin: \(points)."
        let retry = retryNotes.isEmpty
            ? ""
            : "The previous attempt failed these checks: \(retryNotes.joined(separator: " "))"
        return """
        TASK
        Create an avatar-aligned, garment-only asset for the supplied canonical 2D avatar. \
        This is a garment asset for a compositing system, not a finished outfit illustration.

        SOURCE GARMENT
        The first image is the source garment. Preserve its colors, graphic, lettering, logo, pattern, \
        stitching, seams, pockets, zipper or buttons, cuffs, collar, and construction. \
        Do not redesign distinctive details. The closet category is \(category). \
        Use the fitting template \(template.rawValue) (\(template.displayName)). \(template.promptRules)

        CANVAS
        Use a portrait canvas that is 1024 wide and 1536 tall. \
        Position the garment where it sits on the avatar. Keep the entire garment inside the canvas. \
        \(landmarkLine)

        OUTPUT
        Output only the garment and its fabric. Do not include the avatar's face, hair, skin, hands, body, \
        or background. Keep real openings transparent. Match the avatar's illustration style without changing \
        the garment's identity. If a third image is included, it is only a white body silhouette for alignment. \
        Do not copy that silhouette into the garment.

        DO NOT
        Return a picture of the avatar wearing the garment. Do not invent logos, labels, or a back view. \
        Do not close openings that should show a layer underneath. Do not clip the hem, cuffs, or hood.
        \(retry)
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
}
