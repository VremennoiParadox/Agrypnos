import Foundation

final class BrightnessRampController {
    private var timer: Timer?

    var isRunning: Bool { timer != nil }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    func start(from: Double, to: Double, duration: TimeInterval) {
        cancel()
        if duration <= 0 || abs(to - from) < 0.004 {
            BrightnessFloorController.set(to)
            return
        }
        let startDate = Date()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            let t = min(max(Date().timeIntervalSince(startDate) / duration, 0), 1)
            BrightnessFloorController.set(from + (to - from) * t)
            if t >= 1 {
                self?.cancel()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
