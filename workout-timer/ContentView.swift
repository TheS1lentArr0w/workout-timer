import SwiftUI

func formatTime(_ s: Int) -> String {
    String(format: "%d:%02d", s / 60, s % 60)
}

struct ContentView: View {
    @State private var blocks: [Block] = [
        Block(steps: [Step(label: "Warm up", seconds: 300)]),
        Block(repeatCount: 6, isGroup: true, steps: [
            Step(label: "Fast", seconds: 30),
            Step(label: "Slow", seconds: 90)
        ]),
        Block(steps: [Step(label: "Cool down", seconds: 300)])
    ]
    @StateObject private var runner = Runner()
    @State private var running = false

    var body: some View {
        NavigationStack {
            List {
                ForEach($blocks) { $block in
                    BlockView(block: $block)
                }
                .onDelete { blocks.remove(atOffsets: $0) }
                .onMove { blocks.move(fromOffsets: $0, toOffset: $1) }

                Section {
                    Button("Add timer") {
                        blocks.append(Block(steps: [Step(label: "Timer", seconds: 60)]))
                    }
                    Button("Add repeat group") {
                        blocks.append(Block(repeatCount: 2, isGroup: true, steps: [
                            Step(label: "On", seconds: 30),
                            Step(label: "Off", seconds: 30)
                        ]))
                    }
                }
            }
            .navigationTitle("Timers")
            .toolbar { EditButton() }
            .safeAreaInset(edge: .bottom) {
                Button {
                    runner.start(blocks)
                    running = true
                } label: {
                    Text("Start").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(blocks.isEmpty)
                .padding()
            }
            .fullScreenCover(isPresented: $running) {
                RunView(runner: runner)
            }
        }
    }
}

struct BlockView: View {
    @Binding var block: Block

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if block.isGroup {
                Stepper("Repeat ×\(block.repeatCount)", value: $block.repeatCount, in: 1...99)
                    .font(.headline)
            }
            ForEach($block.steps) { $step in
                StepRow(step: $step)
            }
            .onDelete { block.steps.remove(atOffsets: $0) }

            if block.isGroup {
                Button("Add step") {
                    block.steps.append(Step(label: "Step", seconds: 30))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StepRow: View {
    @Binding var step: Step

    private var minutes: Binding<Int> {
        Binding(
            get: { step.seconds / 60 },
            set: { step.seconds = max(0, $0) * 60 + step.seconds % 60 }
        )
    }
    private var seconds: Binding<Int> {
        Binding(
            get: { step.seconds % 60 },
            set: { step.seconds = (step.seconds / 60) * 60 + min(max(0, $0), 59) }
        )
    }

    var body: some View {
        HStack {
            TextField("Label", text: $step.label)
            TextField("m", value: minutes, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 52)
            Text("m")
            TextField("s", value: seconds, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 52)
            Text("s")
        }
    }
}

struct RunView: View {
    @ObservedObject var runner: Runner
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(runner.current?.label ?? "Done")
                .font(.title)
            if let step = runner.current, let r = step.round, let n = step.totalRounds, n > 1 {
                Text("Round \(r) of \(n)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Text(formatTime(runner.remaining))
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let next = runner.queue.first {
                Text("Next: \(next.label) · \(formatTime(next.seconds))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 16) {
                Button(runner.isPaused ? "Resume" : "Pause") {
                    runner.isPaused ? runner.resume() : runner.pause()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Stop") {
                    runner.stop()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }
            .padding()
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: runner.current == nil) { _, finished in
                if finished { dismiss() }
            }
        }
    }
}
