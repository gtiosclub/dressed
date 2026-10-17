import SwiftUI

/// Neutral vector stand-ins for the prototype's garment photos.
struct GarmentArtwork: View {
    let category: ClothingCategory

    var body: some View {
        Canvas { context, size in
            let scale = CGAffineTransform(scaleX: size.width / 100, y: size.height / 100)
            let color = Color(.systemGray)
            var garment = Path()

            switch category {
            case .tops, .outerwear:
                garment.move(to: CGPoint(x: 35, y: 18))
                for point in [
                    CGPoint(x: 20, y: 26), CGPoint(x: 10, y: 44),
                    CGPoint(x: 22, y: 50), CGPoint(x: 28, y: 42),
                    CGPoint(x: 28, y: 84), CGPoint(x: 72, y: 84),
                    CGPoint(x: 72, y: 42), CGPoint(x: 78, y: 50),
                    CGPoint(x: 90, y: 44), CGPoint(x: 80, y: 26),
                    CGPoint(x: 65, y: 18)
                ] { garment.addLine(to: point) }
                garment.addQuadCurve(to: CGPoint(x: 35, y: 18), control: CGPoint(x: 50, y: 34))
            case .pants:
                garment.move(to: CGPoint(x: 30, y: 12))
                for point in [
                    CGPoint(x: 70, y: 12), CGPoint(x: 74, y: 88),
                    CGPoint(x: 55, y: 88), CGPoint(x: 50, y: 40),
                    CGPoint(x: 45, y: 88), CGPoint(x: 26, y: 88)
                ] { garment.addLine(to: point) }
            case .skirts:
                garment.move(to: CGPoint(x: 36, y: 14))
                for point in [
                    CGPoint(x: 64, y: 14), CGPoint(x: 82, y: 86),
                    CGPoint(x: 18, y: 86)
                ] { garment.addLine(to: point) }
            case .dresses:
                garment.move(to: CGPoint(x: 35, y: 17))
                for point in [
                    CGPoint(x: 22, y: 25), CGPoint(x: 14, y: 42),
                    CGPoint(x: 27, y: 49), CGPoint(x: 33, y: 39),
                    CGPoint(x: 34, y: 57), CGPoint(x: 19, y: 86),
                    CGPoint(x: 81, y: 86), CGPoint(x: 66, y: 57),
                    CGPoint(x: 67, y: 39), CGPoint(x: 73, y: 49),
                    CGPoint(x: 86, y: 42), CGPoint(x: 78, y: 25),
                    CGPoint(x: 65, y: 17)
                ] { garment.addLine(to: point) }
                garment.addQuadCurve(to: CGPoint(x: 35, y: 17), control: CGPoint(x: 50, y: 32))
            case .shoes:
                garment.move(to: CGPoint(x: 12, y: 56))
                for point in [
                    CGPoint(x: 34, y: 50), CGPoint(x: 44, y: 60),
                    CGPoint(x: 82, y: 62)
                ] { garment.addLine(to: point) }
                garment.addQuadCurve(to: CGPoint(x: 92, y: 74), control: CGPoint(x: 92, y: 63))
                for point in [
                    CGPoint(x: 92, y: 82), CGPoint(x: 12, y: 82)
                ] { garment.addLine(to: point) }
            case .accessories:
                garment.move(to: CGPoint(x: 22, y: 20))
                garment.addQuadCurve(to: CGPoint(x: 50, y: 59), control: CGPoint(x: 36, y: 57))
                garment.addQuadCurve(to: CGPoint(x: 78, y: 20), control: CGPoint(x: 64, y: 57))
                context.stroke(garment.applying(scale), with: .color(color), lineWidth: max(2, size.width * 0.025))
                let pendant = Path(ellipseIn: CGRect(x: 44, y: 56, width: 12, height: 12))
                context.fill(pendant.applying(scale), with: .color(color))
                return
            case .other:
                garment.move(to: CGPoint(x: 29, y: 14))
                for point in [
                    CGPoint(x: 18, y: 21), CGPoint(x: 12, y: 35),
                    CGPoint(x: 23, y: 40), CGPoint(x: 27, y: 34),
                    CGPoint(x: 27, y: 54), CGPoint(x: 73, y: 54),
                    CGPoint(x: 73, y: 34), CGPoint(x: 77, y: 40),
                    CGPoint(x: 88, y: 35), CGPoint(x: 82, y: 21),
                    CGPoint(x: 71, y: 14), CGPoint(x: 60, y: 21),
                    CGPoint(x: 40, y: 21)
                ] { garment.addLine(to: point) }
                garment.addLine(to: CGPoint(x: 29, y: 14))
            }

            garment.closeSubpath()
            context.fill(garment.applying(scale), with: .color(color))
            if category == .other {
                var lower = Path()
                lower.move(to: CGPoint(x: 30, y: 57))
                for point in [
                    CGPoint(x: 70, y: 57), CGPoint(x: 73, y: 84),
                    CGPoint(x: 56, y: 84), CGPoint(x: 50, y: 64),
                    CGPoint(x: 44, y: 84), CGPoint(x: 27, y: 84)
                ] { lower.addLine(to: point) }
                lower.closeSubpath()
                context.fill(lower.applying(scale), with: .color(color))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
