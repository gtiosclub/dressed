import Metal
import MetalKit
import SwiftUI
import UIKit

struct TryOnGPUVertex {
    var x: Float
    var y: Float
    var u: Float
    var v: Float
}

struct TryOnGPUUniforms {
    var pivotX: Float
    var pivotY: Float
    var translationX: Float
    var translationY: Float
    var scaleX: Float
    var scaleY: Float
    var rotation: Float
    var hasOcclusion: Float
    var occlusionPivotX: Float
    var occlusionPivotY: Float
    var occlusionTranslationX: Float
    var occlusionTranslationY: Float
    var occlusionScaleX: Float
    var occlusionScaleY: Float
    var occlusionRotation: Float
    var pad: Float
}

struct TryOnMetalCanvas: UIViewRepresentable {
    var scene: TryOnScene
    @Binding var note: String?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.framebufferOnly = true
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.94, green: 0.93, blue: 0.91, alpha: 1)
        view.delegate = context.coordinator
        context.coordinator.prepare(device: view.device)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.scene = scene
        if context.coordinator.loadedEpoch != scene.textureEpoch {
            context.coordinator.loadedEpoch = scene.textureEpoch
            context.coordinator.textures.removeAll()
        }
        view.setNeedsDisplay()
        let nextNote = context.coordinator.note
        if note != nextNote {
            DispatchQueue.main.async { note = nextNote }
        }
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var scene = TryOnScene(textureEpoch: 0, items: [])
        var loadedEpoch = -1
        var note: String?
        var textures: [String: MTLTexture] = [:]
        private var device: MTLDevice?
        private var pipeline: MTLRenderPipelineState?
        private var sampler: MTLSamplerState?
        private var commandQueue: MTLCommandQueue?
        private var emptyTexture: MTLTexture?

        func prepare(device: MTLDevice?) {
            guard let device, pipeline == nil else { return }
            self.device = device
            commandQueue = device.makeCommandQueue()
            let descriptor = MTLSamplerDescriptor()
            descriptor.minFilter = .linear
            descriptor.magFilter = .linear
            descriptor.sAddressMode = .clampToEdge
            descriptor.tAddressMode = .clampToEdge
            sampler = device.makeSamplerState(descriptor: descriptor)
            emptyTexture = makeTexture(device: device, width: 1, height: 1, bytes: [0, 0, 0, 0])
            do {
                let library = try device.makeLibrary(source: Self.shader, options: nil)
                guard let vertex = library.makeFunction(name: "garment_vertex"),
                      let fragment = library.makeFunction(name: "garment_fragment") else {
                    note = "The outfit renderer is missing a shader."
                    return
                }
                let pipelineDescriptor = MTLRenderPipelineDescriptor()
                pipelineDescriptor.vertexFunction = vertex
                pipelineDescriptor.fragmentFunction = fragment
                pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
                pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
                pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
                pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
                pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
                pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                pipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                note = nil
            } catch {
                note = "The outfit renderer could not start."
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let device, let pipeline, let commandQueue, let sampler, let emptyTexture,
                  let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor,
                  let buffer = commandQueue.makeCommandBuffer(),
                  let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentSamplerState(sampler, index: 0)
            for item in scene.items {
                guard let colorTexture = texture(for: item.imagePath, device: device) else { continue }
                let vertices = vertices(for: item)
                guard !vertices.isEmpty,
                      let vertexBuffer = device.makeBuffer(
                        bytes: vertices,
                        length: MemoryLayout<TryOnGPUVertex>.stride * vertices.count,
                        options: .storageModeShared
                      ) else { continue }
                let indices = indices(for: item, vertexCount: vertices.count)
                guard !indices.isEmpty,
                      let indexBuffer = device.makeBuffer(
                        bytes: indices,
                        length: MemoryLayout<UInt32>.stride * indices.count,
                        options: .storageModeShared
                      ) else { continue }
                var uniforms = uniforms(for: item)
                let occlusion = item.occlusionPath.flatMap { self.texture(for: $0, device: device) } ?? emptyTexture
                encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                encoder.setVertexBytes(&uniforms, length: MemoryLayout<TryOnGPUUniforms>.stride, index: 1)
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<TryOnGPUUniforms>.stride, index: 0)
                encoder.setFragmentTexture(colorTexture, index: 0)
                encoder.setFragmentTexture(occlusion, index: 1)
                encoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: indices.count,
                    indexType: .uint32,
                    indexBuffer: indexBuffer,
                    indexBufferOffset: 0
                )
            }
            encoder.endEncoding()
            buffer.present(drawable)
            buffer.commit()
        }

        private func vertices(for item: TryOnDrawItem) -> [TryOnGPUVertex] {
            if let mesh = item.mesh, !mesh.vertices.isEmpty {
                return mesh.vertices.map {
                    TryOnGPUVertex(x: $0.x, y: $0.y, u: $0.u, v: $0.v)
                }
            }
            let rect = item.bounds
            return [
                TryOnGPUVertex(x: Float(rect.x), y: Float(rect.y), u: Float(rect.x), v: Float(rect.y)),
                TryOnGPUVertex(x: Float(rect.x + rect.width), y: Float(rect.y), u: Float(rect.x + rect.width), v: Float(rect.y)),
                TryOnGPUVertex(x: Float(rect.x + rect.width), y: Float(rect.y + rect.height), u: Float(rect.x + rect.width), v: Float(rect.y + rect.height)),
                TryOnGPUVertex(x: Float(rect.x), y: Float(rect.y + rect.height), u: Float(rect.x), v: Float(rect.y + rect.height))
            ]
        }

        private func indices(for item: TryOnDrawItem, vertexCount: Int) -> [UInt32] {
            if let mesh = item.mesh, mesh.indices.count >= 3, mesh.indices.allSatisfy({ Int($0) < vertexCount }) {
                return mesh.indices
            }
            return [0, 1, 2, 0, 2, 3]
        }

        private func uniforms(for item: TryOnDrawItem) -> TryOnGPUUniforms {
            let pivot = item.bounds.center
            let occlusionPivot = item.occlusionBounds?.center ?? TryOnPoint(x: 0.5, y: 0.5)
            let occlusion = item.occlusionPlacement
            return TryOnGPUUniforms(
                pivotX: Float(pivot.x),
                pivotY: Float(pivot.y),
                translationX: Float(item.placement.translation.x),
                translationY: Float(item.placement.translation.y),
                scaleX: Float(item.placement.scaleX),
                scaleY: Float(item.placement.scaleY),
                rotation: Float(item.placement.rotationDegrees * .pi / 180),
                hasOcclusion: item.occlusionPath == nil ? 0 : 1,
                occlusionPivotX: Float(occlusionPivot.x),
                occlusionPivotY: Float(occlusionPivot.y),
                occlusionTranslationX: Float(occlusion?.translation.x ?? 0),
                occlusionTranslationY: Float(occlusion?.translation.y ?? 0),
                occlusionScaleX: Float(occlusion?.scaleX ?? 1),
                occlusionScaleY: Float(occlusion?.scaleY ?? 1),
                occlusionRotation: Float((occlusion?.rotationDegrees ?? 0) * .pi / 180),
                pad: 0
            )
        }

        private func texture(for path: String, device: MTLDevice) -> MTLTexture? {
            if let cached = textures[path] { return cached }
            guard TryOnLibrary.validatePNG(at: URL(fileURLWithPath: path)) else {
                #if DEBUG
                NSLog("[TryOn] Metal skipped unreadable texture path=%@", path)
                #endif
                note = "Outfit image could not be displayed."
                return nil
            }
            guard let image = UIImage(contentsOfFile: path)?.cgImage,
                  let bytes = TryOnBitmap.rgba(from: image),
                  let texture = makeTexture(device: device, width: bytes.width, height: bytes.height, bytes: bytes.bytes) else {
                #if DEBUG
                NSLog("[TryOn] Metal texture upload failed path=%@", path)
                #endif
                note = "Outfit image could not be displayed."
                return nil
            }
            textures[path] = texture
            return texture
        }

        private func makeTexture(device: MTLDevice, width: Int, height: Int, bytes: [UInt8]) -> MTLTexture? {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false
            )
            descriptor.usage = [.shaderRead]
            guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
            bytes.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                texture.replace(
                    region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0,
                    withBytes: base,
                    bytesPerRow: width * 4
                )
            }
            return texture
        }

        private static let shader = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float2 position;
            float2 uv;
        };

        struct Uniforms {
            float2 pivot;
            float2 translation;
            float2 scale;
            float rotation;
            float hasOcclusion;
            float2 occlusionPivot;
            float2 occlusionTranslation;
            float2 occlusionScale;
            float occlusionRotation;
            float pad;
        };

        struct VertexOut {
            float4 position [[position]];
            float2 uv;
            float2 canvasPos;
        };

        float2 moved(float2 point, float2 pivot, float2 translation, float2 scale, float rotation) {
            float2 delta = (point - pivot) * scale;
            float cosine = cos(rotation);
            float sine = sin(rotation);
            float2 rotated = float2(delta.x * cosine - delta.y * sine, delta.x * sine + delta.y * cosine);
            return rotated + pivot + translation;
        }

        vertex VertexOut garment_vertex(uint vid [[vertex_id]],
                                         constant VertexIn *vertices [[buffer(0)]],
                                         constant Uniforms &uniforms [[buffer(1)]]) {
            VertexIn input = vertices[vid];
            float2 canvas = moved(input.position, uniforms.pivot, uniforms.translation, uniforms.scale, uniforms.rotation);
            VertexOut output;
            output.canvasPos = canvas;
            output.position = float4(canvas.x * 2.0 - 1.0, 1.0 - canvas.y * 2.0, 0.0, 1.0);
            output.uv = input.uv;
            return output;
        }

        float2 restored(float2 canvas, float2 pivot, float2 translation, float2 scale, float rotation) {
            float2 delta = canvas - translation - pivot;
            float cosine = cos(rotation);
            float sine = sin(rotation);
            float2 rotated = float2(delta.x * cosine + delta.y * sine, -delta.x * sine + delta.y * cosine);
            float2 safeScale = max(scale, float2(0.0001, 0.0001));
            return rotated / safeScale + pivot;
        }

        fragment float4 garment_fragment(VertexOut input [[stage_in]],
                                          constant Uniforms &uniforms [[buffer(0)]],
                                          texture2d<float> colorTex [[texture(0)]],
                                          texture2d<float> occlusionTex [[texture(1)]],
                                          sampler colorSampler [[sampler(0)]]) {
            float4 color = colorTex.sample(colorSampler, input.uv);
            if (uniforms.hasOcclusion > 0.5) {
                float2 local = restored(
                    input.canvasPos,
                    uniforms.occlusionPivot,
                    uniforms.occlusionTranslation,
                    uniforms.occlusionScale,
                    uniforms.occlusionRotation
                );
                if (local.x >= 0.0 && local.y >= 0.0 && local.x <= 1.0 && local.y <= 1.0) {
                    float covered = occlusionTex.sample(colorSampler, local).a;
                    color.rgb *= (1.0 - covered);
                    color.a *= (1.0 - covered);
                }
            }
            return color;
        }
        """
    }
}
