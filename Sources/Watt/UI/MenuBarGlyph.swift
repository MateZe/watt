import SwiftUI
import WattCore

struct MenuBarGlyph: View {
    let states: [HarnessUsageState]
    let claudeSelection: MenuBarMetric
    let codexSelection: MenuBarMetric

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .semibold))

            statusText
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .help(detailText)
        .accessibilityLabel(detailText)
    }

    /// A single Text lets MenuBarExtra measure changing provider content without
    /// clipping. macOS renders status-item text monochromatically, so the menu
    /// bar stays clean while the popover carries the provider colors and marks.
    private var statusText: Text {
        guard !states.isEmpty else { return Text("Watt") }

        let sharesMetric = states.count > 1
            && Set(states.map { selection(for: $0.harness).name(for: $0.harness) }).count == 1
        var text = Text("")
        for (index, state) in states.enumerated() {
            if index > 0 { text = text + Text("  ·  ") }
            let metric = selection(for: state.harness)
            let value = selectedLimit(for: state)?.roundedPercentage.map { "\($0)%" } ?? "Unavailable"
            text = text
                + Text(state.harness.name).bold()
                + Text(sharesMetric ? " \(value)" : " \(metric.name(for: state.harness)) \(value)")
        }
        return text
    }

    private func selectedLimit(for state: HarnessUsageState) -> UsageLimit? {
        state.snapshot.flatMap { selection(for: state.harness).limit(in: $0) }
    }

    private func selection(for harness: HarnessKind) -> MenuBarMetric {
        harness == .claude ? claudeSelection : codexSelection
    }

    private var detailText: String {
        let metrics = states.map { state in
            let selection = selection(for: state.harness)
            let value = selectedLimit(for: state)?.roundedPercentage.map { "\($0)%" } ?? "Unavailable"
            return "\(state.harness.name) \(selection.name(for: state.harness)) · \(value)"
        }
        return (["Watt"] + metrics).joined(separator: "\n")
    }
}
