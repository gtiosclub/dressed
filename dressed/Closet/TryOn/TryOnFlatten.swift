import UIKit

enum TryOnFlatten {
    static func image(scene: TryOnScene, canvas: TryOnCanvas) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: canvas.width, height: canvas.height)
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            for item in scene.items {
                guard let source = UIImage(contentsOfFile: item.imagePath) else { continue }
                let context = renderer.cgContext
                context.saveGState()
                let pivot = CGPoint(
                    x: item.bounds.center.x * size.width,
                    y: item.bounds.center.y * size.height
                )
                let placement = item.placement
                context.translateBy(
                    x: pivot.x + placement.translation.x * size.width,
                    y: pivot.y + placement.translation.y * size.height
                )
                let radians = CGFloat(placement.rotationDegrees * .pi / 180)
                let cosine = cos(radians)
                let sine = sin(radians)
                context.concatenate(CGAffineTransform(a: cosine, b: sine, c: -sine, d: cosine, tx: 0, ty: 0))
                context.scaleBy(x: placement.scaleX, y: placement.scaleY)
                context.translateBy(x: -pivot.x, y: -pivot.y)
                source.draw(in: CGRect(origin: .zero, size: size))
                context.restoreGState()
            }
        }
        return rendered.cgImage
    }
}
