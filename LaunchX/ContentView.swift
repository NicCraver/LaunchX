import Carbon.HIToolbox
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isFocused: Bool
    @State private var window: NSWindow?

    var body: some View {
        VStack(spacing: 0) {
            // Search Header
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)

                TextField("LaunchX Search...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 26, weight: .light))
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .onSubmit {
                        viewModel.openSelected()
                    }
                    // Attach Key Event Monitor
                    .background(
                        KeyEventHandler { event in
                            handleKeyEvent(event)
                        }
                    )
            }
            .padding(20)

            // Results or Empty State
            if !viewModel.results.isEmpty {
                Divider()
                ResultsListView(viewModel: viewModel)
            } else if !viewModel.searchText.isEmpty {
                Divider()
                // No results state
                VStack {
                    Text("No results found.")
                        .foregroundColor(.secondary)
                        .padding()
                }
            } else {
                Divider()
                EmptyStateView()
            }
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        .cornerRadius(16)
        .frame(width: 650)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .fixedSize(horizontal: false, vertical: true)
        .background(WindowAccessor(window: $window))
        .background(
            GeometryReader { geo in
                Color.clear.onChange(of: geo.size) { newSize in
                    resizeWindow(to: newSize)
                }
            }
        )
        // 窗口出现或成为焦点时，强制输入框获得焦点
        .onAppear {
            DispatchQueue.main.async { isFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
            _ in
            // Re-focus when window becomes key (e.g. triggered via HotKey)
            DispatchQueue.main.async {
                isFocused = true
            }
        }
    }

    private func resizeWindow(to size: CGSize) {
        guard let window = window else { return }
        let currentFrame = window.frame
        let newHeight = size.height
        let heightDelta = newHeight - currentFrame.height

        // Only resize if significant change to avoid jitter
        if abs(heightDelta) > 0.5 {
            // Resize from top (keeping top-left corner fixed visually, or centered depending on preference)
            // Usually spotlight grows downwards.
            // Origin Y is at the bottom in Cocoa screen coordinates.
            // So to grow down, we must lower the origin.y by the delta.
            let newOriginY = currentFrame.origin.y - heightDelta

            let newFrame = NSRect(
                x: currentFrame.origin.x,
                y: newOriginY,
                width: size.width,
                height: newHeight
            )
            window.setFrame(newFrame, display: true, animate: false)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Only handle key down
        guard event.type == .keyDown else { return event }

        switch Int(event.keyCode) {
        case kVK_UpArrow:
            viewModel.moveSelectionUp()
            return nil  // Consume event so TextField doesn't move cursor awkwardly
        case kVK_DownArrow:
            viewModel.moveSelectionDown()
            return nil
        case kVK_Escape:
            PanelManager.shared.hidePanel()
            return nil
        default:
            // Emacs-style navigation: Ctrl+N (Down), Ctrl+P (Up)
            if event.modifierFlags.contains(.control) {
                switch Int(event.keyCode) {
                case kVK_ANSI_N:
                    viewModel.moveSelectionDown()
                    return nil
                case kVK_ANSI_P:
                    viewModel.moveSelectionUp()
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }
}

// MARK: - Results List

struct ResultsListView: View {
    @ObservedObject var viewModel: SearchViewModel
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) {
                        index, item in
                        ResultRowView(item: item, isSelected: index == viewModel.selectedIndex)
                            .id(index)
                            .onTapGesture {
                                viewModel.selectedIndex = index
                                viewModel.openSelected()
                            }
                    }
                }
                .padding(.vertical, 10)
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                contentHeight = geo.size.height
                            }
                            .onChange(of: geo.size.height) { newHeight in
                                contentHeight = newHeight
                            }
                    }
                )
            }
            // Dynamic height: fit content but cap at 350
            // Initial height 200 ensures there is space to render and measure content
            .frame(height: contentHeight > 0 ? min(contentHeight, 350) : 200)
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}

struct ResultRowView: View {
    let item: SearchResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                Text(item.path)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    var body: some View {
        HStack {
            Text("Type to search files...")
                .foregroundColor(.secondary)
                .font(.callout)
            Spacer()

            Text("⏎ to open")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(20)
    }
}

// MARK: - Helpers

// Helper for Acrylic/Blur background
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Helper to intercept key events
struct KeyEventHandler: NSViewRepresentable {
    let handler: (NSEvent) -> NSEvent?

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.handler = handler
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class KeyView: NSView {
        var handler: ((NSEvent) -> NSEvent?)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // Remove existing monitor if any
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }

            if window != nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
                    [weak self] event in
                    return self?.handler?(event) ?? event
                }
            }
        }

        deinit {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

// Helper to access the underlying NSWindow
struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
