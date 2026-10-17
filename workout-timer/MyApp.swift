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
    @Published private(set) var queue: [Step] = []
    private var endDate = Date()
    private var ticker: Timer?

    func start(_ blocks: [Block]) {
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

    func stop() {
        ticker?.invalidate()
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
