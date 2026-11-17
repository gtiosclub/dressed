import Foundation
import Observation
import QuartzCore

// Turntable state for the 3D avatar. Dragging sideways spins it around its vertical axis;
// letting go keeps it coasting until damping stops it. Each AvatarView owns one.
@Observable
final class AvatarOrbit {
    /// Radians around the vertical axis. 0 faces the camera; positive turns the avatar's front to the right.
    private(set) var yaw: Double = 0

    @ObservationIgnored private var velocity: Double = 0  // radians per second
    @ObservationIgnored private var dragStartYaw: Double?
    @ObservationIgnored private var target: Double?
    @ObservationIgnored private var ticker: FrameTicker?

    /// A drag across the full view width turns the avatar this far.
    private let radiansPerViewWidth = Double.pi * 1.25
    /// Higher stops a fling sooner.
    private let damping = 3.5
    private let maxSpeed = Double.pi * 4

    func dragChanged(translation: CGFloat, viewWidth: CGFloat) {
        if dragStartYaw == nil {
            ticker?.stop()
            velocity = 0
            target = nil
            dragStartYaw = yaw
        }
        yaw = (dragStartYaw ?? yaw) + Double(translation / max(viewWidth, 1)) * radiansPerViewWidth
    }

    func dragEnded(velocity pointsPerSecond: CGFloat, viewWidth: CGFloat) {
        dragStartYaw = nil
        let speed = Double(pointsPerSecond / max(viewWidth, 1)) * radiansPerViewWidth
        velocity = min(max(speed, -maxSpeed), maxSpeed)
        startTicking()
    }

    /// Eases back to facing the camera the short way round.
    func resetToFront() {
        dragStartYaw = nil
        velocity = 0
        yaw = yaw.remainder(dividingBy: 2 * .pi)
        target = 0
        startTicking()
    }

    /// Eases by a fixed step, e.g. for VoiceOver's adjustable action.
    func turn(by radians: Double) {
        dragStartYaw = nil
        velocity = 0
        target = (target ?? yaw) + radians
        startTicking()
    }

    private func startTicking() {
        guard ticker?.isRunning != true else { return }
        ticker = FrameTicker { [weak self] elapsed in
            self?.advance(by: elapsed) ?? false
        }
    }

    /// Moves one frame forward. Returns false once the avatar has settled.
    private func advance(by elapsed: Double) -> Bool {
        if let target {
            yaw += (target - yaw) * (1 - exp(-12 * elapsed))
            guard abs(target - yaw) < 0.001 else { return true }
            yaw = target
            self.target = nil
            return false
        }
        guard abs(velocity) > 0.05 else {
            velocity = 0
            return false
        }
        yaw += velocity * elapsed
        velocity *= exp(-damping * elapsed)
        return true
    }
}

/// Calls `onFrame` with the seconds since the last display refresh until it returns false.
private final class FrameTicker: NSObject {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private let onFrame: (Double) -> Bool

    var isRunning: Bool { link != nil }

    init(onFrame: @escaping (Double) -> Bool) {
        self.onFrame = onFrame
        super.init()
        let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func frame(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard let previous = lastTimestamp else { return }
        // Cap long gaps (e.g. after a hitch) so the avatar never jumps.
        if !onFrame(min(link.timestamp - previous, 1.0 / 30)) {
            stop()
        }
    }
}
