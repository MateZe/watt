import AppKit
import ServiceManagement
import SwiftUI
import WattCore

struct MenuBarView: View {
    @ObservedObject var store: UsageStore
    @Binding var claudeTrackingEnabled: Bool
    @Binding var codexTrackingEnabled: Bool
    @Binding var claudeMenuBarMetric: String
    @Binding var codexMenuBarMetric: String
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .frame(height: 43)

            Divider().opacity(0.42)

            usage
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            Divider().opacity(0.55)

            controls
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
        }
        .frame(width: 330)
        .background(.background)
        // MenuBarExtra's window can inherit text-selection cursor regions from
        // its SwiftUI content. Disable selection semantically, then explicitly
        // claim the standard pointer on systems that support pointer styles.
        .textSelection(.disabled)
        .modifier(HUDPointerStyle())
        .overlay {
            HUDCursorGuard()
                .accessibilityHidden(true)
        }
        .onAppear {
            store.refresh(reason: .popover)
            refreshLoginItemStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Watt")
                .font(.system(size: 14, weight: .semibold))
            Spacer()

            Button {
                store.refresh(reason: .manual)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                    .animation(store.isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: store.isRefreshing)
            }
            .buttonStyle(.plain)
            .disabled(store.isRefreshing || !hasEnabledProvider)
            .help("Refresh usage")
        }
    }

    private var usage: some View {
        VStack(spacing: 14) {
            ForEach(Array(HarnessKind.allCases.enumerated()), id: \.element) { index, harness in
                if index > 0 {
                    Divider().opacity(0.42)
                }
                providerSection(
                    harness,
                    state: store.states.first { $0.harness == harness }
                )
            }
        }
    }

    private func providerSection(_ harness: HarnessKind, state: HarnessUsageState?) -> some View {
        let trackingEnabled = isTrackingEnabled(harness)

        return VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 7) {
                HarnessMark(harness: harness)
                Toggle("Track \(harness.name)", isOn: trackingBinding(for: harness))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help("Track \(harness.name) usage")
                metricPicker(for: harness)
                    .disabled(!trackingEnabled)
                Spacer()
                if let state, let warning = store.warningMessage(for: state) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.orange)
                        .help(warning)
                }
            }

            if trackingEnabled {
                if let snapshot = state?.snapshot {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(snapshot.limits) { limit in
                            VStack(spacing: 6) {
                                UsageRing(limit: limit, harness: harness, size: 58, lineWidth: 4)
                                Text(limit.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(shortReset(for: limit))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .help(UsageFormatting.resetText(for: limit))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    Text(state?.failure?.message ?? unavailableMessage(for: harness))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin)) {
                Label("Launch at Login", systemImage: "power")
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)

            if let loginItemMessage {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .help(loginItemMessage)
            }

            Spacer()

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .keyboardShortcut("q")
        }
        .font(.system(size: 12.5))
    }

    private func metricPicker(for harness: HarnessKind) -> some View {
        let selected = selectedMetric(for: harness)

        return Menu {
            ForEach(MenuBarMetric.supported(for: harness)) { metric in
                Button {
                    setSelectedMetric(metric, for: harness)
                } label: {
                    if metric == selected {
                        Label(metric.name(for: harness), systemImage: "checkmark")
                    } else {
                        Text(metric.name(for: harness))
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "menubar.rectangle")
                Text(selected.name(for: harness))
            }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Metric shown in the menu bar")
    }

    private var hasEnabledProvider: Bool {
        claudeTrackingEnabled || codexTrackingEnabled
    }

    private func isTrackingEnabled(_ harness: HarnessKind) -> Bool {
        harness == .claude ? claudeTrackingEnabled : codexTrackingEnabled
    }

    private func unavailableMessage(for harness: HarnessKind) -> String {
        store.hasCompletedDiscovery
            ? "\(harness.name) usage is unavailable."
            : "Loading \(harness.name) usage…"
    }

    private func trackingBinding(for harness: HarnessKind) -> Binding<Bool> {
        Binding(
            get: { harness == .claude ? claudeTrackingEnabled : codexTrackingEnabled },
            set: { enabled in
                if harness == .claude {
                    claudeTrackingEnabled = enabled
                } else {
                    codexTrackingEnabled = enabled
                }
                store.setTracking(enabled, for: harness)
            }
        )
    }

    private func selectedMetric(for harness: HarnessKind) -> MenuBarMetric {
        let rawValue = harness == .claude ? claudeMenuBarMetric : codexMenuBarMetric
        let metric = MenuBarMetric(rawValue: rawValue) ?? .weekly
        return MenuBarMetric.supported(for: harness).contains(metric) ? metric : .weekly
    }

    private func setSelectedMetric(_ metric: MenuBarMetric, for harness: HarnessKind) {
        if harness == .claude {
            claudeMenuBarMetric = metric.rawValue
        } else {
            codexMenuBarMetric = metric.rawValue
        }
    }

    private func refreshLoginItemStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        loginItemMessage = SMAppService.mainApp.status == .requiresApproval
            ? "Allow Watt in System Settings › General › Login Items."
            : nil
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLoginItemStatus()
        } catch {
            refreshLoginItemStatus()
            loginItemMessage = error.localizedDescription
        }
    }

    private func shortReset(for limit: UsageLimit) -> String {
        guard let date = limit.resetDate else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: date, relativeTo: .now)
        let time = date.formatted(date: .omitted, time: .shortened)
        return "\(relative) · \(time)"
    }

}

private struct HUDPointerStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.pointerStyle(.default)
        } else {
            content
        }
    }
}

/// Keeps Watt's cursor independent from whichever application is active below
/// its nonactivating menu-bar window. Cursor rects alone are ignored while an
/// application is inactive, so the active-always tracking area also responds to
/// cursor updates and mouse movement. Returning nil from hitTest preserves all
/// SwiftUI control interaction beneath this view.
private struct HUDCursorGuard: NSViewRepresentable {
    func makeNSView(context: Context) -> HUDCursorView {
        HUDCursorView()
    }

    func updateNSView(_ nsView: HUDCursorView, context: Context) {
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

private final class HUDCursorView: NSView {
    private var cursorTrackingArea: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        window?.invalidateCursorRects(for: self)
    }

    override func updateTrackingAreas() {
        if let cursorTrackingArea {
            removeTrackingArea(cursorTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .cursorUpdate, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        cursorTrackingArea = trackingArea
        super.updateTrackingAreas()
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(visibleRect, cursor: .arrow)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.arrow.set()
    }
}
