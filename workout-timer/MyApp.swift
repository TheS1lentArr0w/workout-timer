import SwiftUI
import Combine
import UIKit

struct Step: Identifiable {
    let id = UUID()
    var label: String
    var seconds: Int
}

struct Block: Identifiable {
    let id = UUID()
    var repeatCount = 1
    var isGroup = false
    var steps: [Step]

    var flattened: [Step] {
        (0..<repeatCount).flatMap { _ in steps }
    }
}

@MainActor
final class Runner: ObservableObject {
    @Published var current: Step?
    @Published var remaining = 0
    @Published var isPaused = false
    @Published private(set) var queue: [Step] = []
    private var endDate = Date()
    private var pausedRemaining: TimeInterval = 0
    private var ticker: Timer?

    func start(_ blocks: [Block]) {
        isPaused = false
        queue = blocks.flatMap { $0.flattened }
        next()
    }

    private func next() {
        ticker?.invalidate()
        guard !queue.isEmpty else { current = nil; return }
        let step = queue.removeFirst()
        current = step
        endDate = Date().addingTimeInterval(TimeInterval(step.seconds))
        remaining = step.seconds
        startTicker()
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        remaining = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        if remaining == 0 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            next()
        }
    }

    func pause() {
        guard current != nil, !isPaused else { return }
        pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        ticker?.invalidate()
        isPaused = true
    }

    func resume() {
        guard current != nil, isPaused else { return }
        endDate = Date().addingTimeInterval(pausedRemaining)
        isPaused = false
        startTicker()
    }

    func stop() {
        ticker?.invalidate()
        isPaused = false
        queue = []
        current = nil
    }
}

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
