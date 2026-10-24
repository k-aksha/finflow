import Lottie
import SwiftUI
#if os(macOS)
import AppKit
#endif

private struct ScreenScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var screenScale: CGFloat {
        get { self[ScreenScaleKey.self] }
        set { self[ScreenScaleKey.self] = newValue }
    }
}

struct ScreenScaleReader<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width > 500 ? 1 : proxy.size.width / 402
            content()
                .environment(\.screenScale, scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

struct ProportionalImage: View {
    var name: String
    var designWidth: CGFloat
    var designHeight: CGFloat
    @Environment(\.screenScale) private var screenScale

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: designWidth * screenScale, height: designHeight * screenScale)
    }
}

struct CharacterAnimation: View {
    var name: String
    var designWidth: CGFloat
    var designHeight: CGFloat
    var loop: Bool = true
    var fillsCanvas: Bool = false
    var onFinished: (() -> Void)? = nil
    @Environment(\.screenScale) private var screenScale

    var body: some View {
        if fillsCanvas {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
                player
                    .frame(width: designWidth * scale, height: designHeight * scale)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        } else {
            player
                .frame(width: designWidth * screenScale, height: designHeight * screenScale)
        }
    }

    private var player: some View {
        LottieView(animation: .named(name))
            .resizable()
            .playing(loopMode: loop ? .loop : .playOnce)
            .animationDidFinish { completed in
                if completed { onFinished?() }
            }
            .configure { view in
                view.contentMode = .scaleAspectFit
                #if os(macOS)
                view.wantsLayer = true
                view.layer?.backgroundColor = NSColor.clear.cgColor
                view.layer?.masksToBounds = false
                #else
                view.backgroundColor = .clear
                view.clipsToBounds = false
                #endif
            }
            .accessibilityHidden(true)
    }
}

enum NucleusMood {
    case happy
    case focused
    case skeptical
    case done

    var animationName: String {
        switch self {
        case .happy: "CharacterHome"
        case .focused: "CharacterListening"
        case .skeptical: "CharacterAnalyzing"
        case .done: "CharacterDone"
        }
    }
}

struct NucleusAvatar: View {
    var mood: NucleusMood = .happy

    var body: some View {
        CharacterAnimation(
            name: mood.animationName,
            designWidth: 133,
            designHeight: 236
        )
        .id(mood.animationName)
    }
}

struct TimelineFace: View {
    var selected: Bool

    var body: some View {
        ProportionalImage(
            name: selected ? "TimelineFaceActive" : "TimelineFaceIdle",
            designWidth: selected ? 41 : 28,
            designHeight: selected ? 43 : 29
        )
    }
}
