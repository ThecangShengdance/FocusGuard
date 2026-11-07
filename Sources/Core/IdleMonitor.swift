import CoreGraphics
import Foundation

/// 使用系统空闲时间检测：用户长时间没有键鼠输入时，可自动暂停专注。
final class IdleMonitor {
    var isEnabled = false
    var threshold: TimeInterval = 180
    var onIdle: ((TimeInterval) -> Void)?
    var onActivity: (() -> Void)?

    private var timer: Timer?
    private var fired = false

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 5, target: self, selector: #selector(check), userInfo: nil, repeats: true)
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        fired = false
    }

    func reset() {
        fired = false
    }

    var currentIdleSeconds: TimeInterval {
        let mouse = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let keys = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        return min(mouse, keys)
    }

    @objc private func check() {
        guard isEnabled else {
            fired = false
            return
        }
        let idle = currentIdleSeconds
        if idle >= threshold {
            if !fired {
                fired = true
                onIdle?(idle)
            }
        } else if idle < 3, fired {
            fired = false
            onActivity?()
        }
    }
}
