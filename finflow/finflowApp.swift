import Foundation
import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct finflowApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            UserDefaults.standard.set(true, forKey: "hasEnteredFinFlow")
        }
    }

    @State private var session = CaptureSession()
    private let container = ExpenseContainer.make()

    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                if let container {
                    RootView()
                        .environment(session)
                        .modelContainer(container)
                } else {
                    StoreFailureView()
                }
            }
        }
        #if os(macOS)
        .defaultSize(width: 1080, height: 780)
        #endif
        .commands {
            CommandGroup(after: .newItem) {
                Button("Log an Expense") {
                    CaptureLaunch.request()
                    NotificationCenter.default.post(name: CaptureLaunch.notification, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        #if os(macOS)
        MenuBarExtra {
            if let container {
                MenuBarCapture()
                    .environment(session)
                    .modelContainer(container)
            } else {
                Text("FinFlow couldn’t open its saved expenses.")
                    .padding()
            }
        } label: {
            Label("FinFlow", systemImage: session.phase == .listening ? "waveform" : "mic.fill")
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

private enum ExpenseContainer {
    static func make() -> ModelContainer? {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            return try? ModelContainer(
                for: Expense.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        return try? FinFlowStore.container()
    }
}

private struct StoreFailureView: View {
    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 12) {
                Text("FinFlow couldn’t open its saved expenses.")
                    .font(.system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text("Your notes stay on this device. Quit the app and open it again.")
                    .font(.system(size: 15))
                    .foregroundStyle(FinFlowTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(32)
        }
    }
}

struct RootView: View {
    @AppStorage("hasEnteredFinFlow") private var hasEntered = false
    @Environment(CaptureSession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif
    @State private var showSplash = !CaptureLaunch.isPending && !ProcessInfo.processInfo.arguments.contains("-ui-testing")
    #if os(macOS)
    @State private var showMacSettings = false
    #endif
    @State private var tab: AppTab = .home

    var body: some View {
        ScreenScaleReader {
            ZStack {
                if showSplash {
                    splash
                } else if !hasEntered {
                    WelcomeView {
                        hasEntered = true
                    }
                } else {
                    main
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            #if os(macOS)
            if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
            #endif
            if CaptureLaunch.isPending {
                showSplash = false
            }
            consumeLaunchIfReady()
        }
        .onChange(of: hasEntered) { _, entered in
            if entered { consumeLaunchIfReady() }
        }
        .onChange(of: scenePhase) { _, phase in
            #if os(iOS)
            if phase == .background {
                session.stopIfListening()
            }
            #endif
            if phase == .active {
                consumeLaunchIfReady()
            }
        }
        .onOpenURL { url in
            guard url.scheme == "finflow" else { return }
            CaptureLaunch.request()
            showSplash = false
            consumeLaunchIfReady()
        }
        .onReceive(NotificationCenter.default.publisher(for: CaptureLaunch.notification)) { _ in
            consumeLaunchIfReady()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            for _ in 0..<12 {
                consumeLaunchIfReady()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    #if !os(macOS)
    private var usesWideCanvas: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    #endif

    private func consumeLaunchIfReady() {
        guard hasEntered else { return }
        guard CaptureLaunch.isPending else { return }
        showSplash = false
        guard CaptureLaunch.take() else { return }
        session.beginFromLaunch(using: modelContext)
    }

    private var splash: some View {
        ZStack {
            ScreenBackground()
            CharacterAnimation(
                name: "Splash",
                designWidth: 402,
                designHeight: 874,
                loop: false,
                fillsCanvas: true
            ) {
                withAnimation(.easeOut(duration: 0.35)) {
                    showSplash = false
                }
            }
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.easeOut(duration: 0.35)) {
                showSplash = false
            }
        }
    }

    private var main: some View {
        #if os(macOS)
        macMain
        #else
        padOrPhone
        #endif
    }

    #if os(macOS)
    private var macMain: some View {
        ZStack(alignment: .trailing) {
            NavigationStack {
                HStack(spacing: 0) {
                    HomeView()
                        .frame(width: 460)
                    MacTimelineHost()
                        .frame(maxWidth: .infinity)
                }
                .frame(minWidth: 880, minHeight: 640)
                .background { ScreenBackground() }
                .navigationTitle("FinFlow")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showMacSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .accessibilityIdentifier("open-settings")
                    }
                }
                .toolbarBackground(FinFlowTheme.backgroundTop, for: .windowToolbar)
                .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
            }
            if showMacSettings {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .onTapGesture { showMacSettings = false }
                macSettingsPanel
                    .transition(.move(edge: .trailing))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("settings-panel")
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: showMacSettings)
    }

    private var macSettingsPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showMacSettings = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("Close")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(FinFlowTheme.tabSelected, in: Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("close-settings")
                .accessibilityLabel("Close settings")
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 8)
            SettingsView(embedded: true)
        }
        .frame(width: 440)
        .frame(maxHeight: .infinity)
        .background(FinFlowTheme.tabBar)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
        }
        .shadow(color: Color.black.opacity(0.45), radius: 24, x: -8, y: 0)
    }
    #endif

    #if !os(macOS)
    private var padOrPhone: some View {
        Group {
            if usesWideCanvas, tab != .settings {
                HStack(spacing: 0) {
                    HomeView()
                    TimelineView()
                        .frame(minWidth: 360, idealWidth: 420, maxWidth: 520)
                }
            } else {
                ZStack {
                    HomeView()
                        .opacity(tab == .home ? 1 : 0)
                        .allowsHitTesting(tab == .home)
                    TimelineView()
                        .opacity(tab == .ledger ? 1 : 0)
                        .allowsHitTesting(tab == .ledger)
                    SettingsView()
                        .opacity(tab == .settings ? 1 : 0)
                        .allowsHitTesting(tab == .settings)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 10) {
            FlowTabBar(selection: $tab)
                .padding(.bottom, 6)
        }
    }
    #endif
}

#if os(macOS)
private struct MacTimelineHost: View {
    var body: some View {
        GeometryReader { proxy in
            let heightScale = max((proxy.size.height - 16) / 680, 0.7)
            let widthScale = max((proxy.size.width - 300) / 176, 0.7)
            let scale = min(heightScale, widthScale, 1.15)
            TimelineView()
                .environment(\.screenScale, scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
#endif
