import Foundation

// Triangle-mesh builders for the procedural mannequin (shapes live in Mannequin.swift).
// Plain math with no RealityKit, so the geometry can be checked without a device.
// Triangles wind counterclockwise seen from outside, and normals point outward.

struct MannequinMesh {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []

    var isEmpty: Bool { indices.isEmpty }

    mutating func append(_ other: MannequinMesh) {
        let offset = UInt32(positions.count)
        positions += other.positions
        normals += other.normals
        indices += other.indices.map { $0 + offset }
    }
}

/// One cross-section of a lofted part: an ellipse around `center`.
struct LoftRing {
    var center: SIMD3<Float>
    /// Half-width along the part's side axis.
    var width: Float
    /// Half-depth along the part's front axis.
    var depth: Float

    init(_ center: SIMD3<Float>, width: Float, depth: Float) {
        self.center = center
        self.width = width
        self.depth = depth
    }
}

enum MannequinGeometry {
    private static let capRings = 4

    /// A smooth tube through `keys` (Catmull-Rom between them) with rounded, closed ends.
    /// `caps` is how far each rounded end reaches past the first and last ring.
    /// `reference` sets the front axis; use +y for parts that run front to back, like feet.
    static func loft(
        _ keys: [LoftRing],
        sides: Int,
        steps: Int = 4,
        caps: (start: Float, end: Float),
        reference: SIMD3<Float> = [0, 0, 1]
    ) -> MannequinMesh {
        let rings = smoothed(keys, steps: steps)
        let tangents = rings.indices.map { index in
            normalized(rings[min(index + 1, rings.count - 1)].center - rings[max(index - 1, 0)].center)
        }
        guard let first = rings.first, let last = rings.last,
              let startTangent = tangents.first, let endTangent = tangents.last else { return MannequinMesh() }

        // Rounded ends: rings shrink along a quarter circle, then close at a single pole.
        var profile: [(ring: LoftRing, tangent: SIMD3<Float>)] = []
        for step in stride(from: capRings - 1, through: 1, by: -1) {
            profile.append((capRing(first, toward: -startTangent, reach: caps.start, step: step), startTangent))
        }
        profile += zip(rings, tangents).map { (ring: $0, tangent: $1) }
        for step in 1..<capRings {
            profile.append((capRing(last, toward: endTangent, reach: caps.end, step: step), endTangent))
        }

        var mesh = MannequinMesh()
        mesh.positions.append(first.center - startTangent * caps.start)
        for entry in profile {
            let side = normalized(crossProduct(entry.tangent, reference))
            let front = crossProduct(side, entry.tangent)
            for corner in 0..<sides {
                let angle = Float(corner) / Float(sides) * 2 * .pi
                let offset = side * (entry.ring.width * cos(angle)) + front * (entry.ring.depth * sin(angle))
                mesh.positions.append(entry.ring.center + offset)
            }
        }
        let endPole = UInt32(mesh.positions.count)
        mesh.positions.append(last.center + endTangent * caps.end)

        func vertex(_ ring: Int, _ corner: Int) -> UInt32 {
            UInt32(1 + ring * sides + corner % sides)
        }
        let lastRing = profile.count - 1
        for corner in 0..<sides {
            mesh.indices += [0, vertex(0, corner), vertex(0, corner + 1)]
            mesh.indices += [endPole, vertex(lastRing, corner + 1), vertex(lastRing, corner)]
        }
        for ring in 0..<lastRing {
            for corner in 0..<sides {
                mesh.indices += quad(
                    vertex(ring, corner), vertex(ring, corner + 1),
                    vertex(ring + 1, corner), vertex(ring + 1, corner + 1)
                )
            }
        }
        mesh.normals = smoothNormals(mesh.positions, mesh.indices)
        return mesh
    }

    /// A grid in spherical angles: `theta` turns around the vertical axis (0 faces front, a quarter turn is +x)
    /// and `phi` runs down from the top (0). `point` maps (theta, phi) to a position and must return the same
    /// point for every theta at phi = 0. Without `phiLimit` the surface closes at phi = pi; with it, each column
    /// stops at `phiLimit(theta)`, which is how hairlines are cut. `thetaRange` makes an open patch.
    static func surface(
        columns: Int,
        rows: Int,
        thetaRange: ClosedRange<Float>? = nil,
        point: (Float, Float) -> SIMD3<Float>,
        phiLimit: ((Float) -> Float)? = nil
    ) -> MannequinMesh {
        let wraps = thetaRange == nil
        let range = thetaRange ?? 0...(2 * .pi)
        let columnCount = wraps ? columns : columns + 1
        let closed = phiLimit == nil
        let ringCount = closed ? rows - 1 : rows
        let thetas = (0..<columnCount).map { column in
            range.lowerBound + (range.upperBound - range.lowerBound) * Float(column) / Float(columns)
        }

        var mesh = MannequinMesh()
        mesh.positions.append(point(0, 0))
        for row in 1...ringCount {
            for theta in thetas {
                let limit = phiLimit?(theta) ?? .pi
                mesh.positions.append(point(theta, limit * Float(row) / Float(rows)))
            }
        }

        func vertex(_ row: Int, _ column: Int) -> UInt32 {
            UInt32(1 + (row - 1) * columnCount + (wraps ? column % columnCount : column))
        }
        for column in 0..<columns {
            mesh.indices += [0, vertex(1, column), vertex(1, column + 1)]
        }
        for row in 1..<ringCount {
            for column in 0..<columns {
                mesh.indices += quad(
                    vertex(row, column), vertex(row, column + 1),
                    vertex(row + 1, column), vertex(row + 1, column + 1)
                )
            }
        }
        if closed {
            let pole = UInt32(mesh.positions.count)
            mesh.positions.append(point(0, .pi))
            for column in 0..<columns {
                mesh.indices += [pole, vertex(ringCount, column + 1), vertex(ringCount, column)]
            }
        }
        mesh.normals = smoothNormals(mesh.positions, mesh.indices)
        return mesh
    }

    // MARK: - Helpers

    /// Two triangles between a ring (`here`, `beside`) and the next ring along the part (`above`, `aboveBeside`).
    private static func quad(_ here: UInt32, _ beside: UInt32, _ above: UInt32, _ aboveBeside: UInt32) -> [UInt32] {
        [here, above, beside, beside, above, aboveBeside]
    }

    private static func capRing(_ ring: LoftRing, toward direction: SIMD3<Float>, reach: Float, step: Int) -> LoftRing {
        let angle = Float(step) / Float(capRings) * .pi / 2
        return LoftRing(
            ring.center + direction * (sin(angle) * reach),
            width: ring.width * cos(angle),
            depth: ring.depth * cos(angle)
        )
    }

    private static func smoothed(_ keys: [LoftRing], steps: Int) -> [LoftRing] {
        guard keys.count > 1 else { return keys }
        var rings: [LoftRing] = []
        for index in 0..<(keys.count - 1) {
            let before = keys[max(index - 1, 0)]
            let start = keys[index]
            let end = keys[index + 1]
            let after = keys[min(index + 2, keys.count - 1)]
            for step in 0..<steps {
                let amount = Float(step) / Float(steps)
                let center = catmullRom(before.center, start.center, end.center, after.center, amount)
                let size = catmullRom(
                    SIMD2(before.width, before.depth), SIMD2(start.width, start.depth),
                    SIMD2(end.width, end.depth), SIMD2(after.width, after.depth), amount
                )
                rings.append(LoftRing(center, width: max(size.x, 0.001), depth: max(size.y, 0.001)))
            }
        }
        rings.append(keys[keys.count - 1])
        return rings
    }

    /// Area-weighted vertex normals, so shading is smooth across each part.
    private static func smoothNormals(_ positions: [SIMD3<Float>], _ indices: [UInt32]) -> [SIMD3<Float>] {
        var normals = [SIMD3<Float>](repeating: .zero, count: positions.count)
        for triangle in stride(from: 0, to: indices.count - 2, by: 3) {
            let first = Int(indices[triangle])
            let second = Int(indices[triangle + 1])
            let third = Int(indices[triangle + 2])
            let face = crossProduct(positions[second] - positions[first], positions[third] - positions[first])
            normals[first] += face
            normals[second] += face
            normals[third] += face
        }
        return normals.map(normalized)
    }
}

private func catmullRom<Vector: SIMD>(
    _ before: Vector, _ start: Vector, _ end: Vector, _ after: Vector, _ amount: Float
) -> Vector where Vector.Scalar == Float {
    let squared = amount * amount
    let cubed = squared * amount
    let linear = (end - before) * amount
    let quadratic = (before * 2 - start * 5 + end * 4 - after) * squared
    let cubic = (start * 3 - before - end * 3 + after) * cubed
    return (start * 2 + linear + quadratic + cubic) * 0.5
}

private func crossProduct(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3(lhs.y * rhs.z - lhs.z * rhs.y, lhs.z * rhs.x - lhs.x * rhs.z, lhs.x * rhs.y - lhs.y * rhs.x)
}

private func normalized(_ vector: SIMD3<Float>) -> SIMD3<Float> {
    let length = (vector * vector).sum().squareRoot()
    return length > 1e-12 ? vector / length : SIMD3(0, 1, 0)
}
