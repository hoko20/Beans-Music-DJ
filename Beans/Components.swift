import SwiftUI
import UIKit

// MARK: - 工具

func beansSongCountText(_ count: Int) -> String { "\(count) 首" }

func beansTimeString(_ seconds: Double) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - 触感反馈（复用生成器实例，避免每次点击创建新对象）

enum BeansHaptics {
    static let enabledKey = "beans.haptics.enabled"

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func prepare() {
        guard isEnabled else { return }
        lightImpact.prepare()
        mediumImpact.prepare()
        selection.prepare()
    }

    static func tap() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }

    static func medium() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    static func select() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }
}

// MARK: - 按压动效

struct GlassPressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? 0.025 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - 背景氛围（液态玻璃需要有可采样的动态内容）

struct GlassBackdrop: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    var customColor: Color? = nil
    var homeMode: Bool = false
    var wallpaperBlur: CGFloat = 0

    private var showCustomBackground: Bool {
        theme.backgroundSyncAll || homeMode
    }

    private var uiStyle: BeansUIStyle {
        uiStyleRaw == "outline" ? .clear : (BeansUIStyle(rawValue: uiStyleRaw) ?? .liquid)
    }

    var body: some View {
        let _ = theme.accent
        let activeBackgroundColor = theme.customBackground(for: colorScheme) ?? customColor
        let activeBackgroundImage = theme.customBackgroundImage(for: colorScheme)
        ZStack {
            if uiStyle == .nativeClean, !showCustomBackground || (activeBackgroundImage == nil && activeBackgroundColor == nil) {
                Color(UIColor.systemBackground)
            } else if let image = activeBackgroundImage, showCustomBackground {
                WallpaperImage(image: image, blurRadius: wallpaperBlur)
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [.black.opacity(0.35), .black.opacity(0.55)]
                        : [.black.opacity(0.08), .black.opacity(0.18)],
                    startPoint: .top, endPoint: .bottom
                )
            } else if showCustomBackground, let activeBackgroundColor {
                LinearGradient(
                    colors: [activeBackgroundColor.opacity(0.9), activeBackgroundColor.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                LinearGradient.beansBackdrop
            }
            if uiStyle != .nativeClean {
                Circle()
                    .fill(Color.beansAmber.opacity(0.14))
                    .frame(width: 340, height: 340)
                    .blur(radius: 100)
                    .offset(x: 150, y: -300)
                Circle()
                    .fill(Color.beansSage.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 110)
                    .offset(x: -160, y: 340)
            }
        }
        .ignoresSafeArea()
    }
}

struct WallpaperImage: View {
    let image: UIImage
    var blurRadius: CGFloat = 0

    private static func isSmall(_ image: UIImage) -> Bool {
        image.size.width * image.size.height < 480_000
    }

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .blur(radius: max(Self.isSmall(image) ? 5 : 0, blurRadius))
        }
        .ignoresSafeArea()
    }
}

// MARK: - 全局玻璃容器

struct BeansGlass<S: Shape>: View {
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue

    let shape: S
    var forceLiquid = false

    private var uiStyle: BeansUIStyle {
        uiStyleRaw == "outline" ? .clear : (BeansUIStyle(rawValue: uiStyleRaw) ?? .liquid)
    }

    private var isLiquid: Bool {
        forceLiquid || uiStyle == .liquid || uiStyle == .nativeClean
    }

    var body: some View {
        if isLiquid {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    shape
                        .fill(.clear)
                        .glassEffect(.clear, in: shape)
                }
            } else {
                shape.fill(.ultraThinMaterial)
            }
        } else {
            switch uiStyle {
            case .clear, .liquid:
                shape.fill(.ultraThinMaterial)
            case .compact:
                shape.fill(Color.beansGlassFill.opacity(0.74))
            case .nativeClean:
                shape.fill(Color.beansGlassFill.opacity(0.62))
            }
        }
    }
}

struct BeansSurface<S: Shape>: View {
    let shape: S

    var body: some View {
        BeansGlass(shape: shape)
    }
}

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    @ViewBuilder var content: () -> Content

    private var uiStyle: BeansUIStyle {
        uiStyleRaw == "outline" ? .clear : (BeansUIStyle(rawValue: uiStyleRaw) ?? .liquid)
    }

    private var resolvedCornerRadius: CGFloat {
        if uiStyle == .compact { return min(cornerRadius, 16) }
        if uiStyle == .nativeClean { return min(cornerRadius, 18) }
        return cornerRadius
    }

    private var resolvedPadding: CGFloat {
        if uiStyle == .compact { return 12 }
        if uiStyle == .nativeClean { return 13 }
        return 16
    }

    var body: some View {
        if uiStyle == .liquid || uiStyle == .nativeClean {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    content()
                        .padding(resolvedPadding)
                        .glassEffect(.clear, in: .rect(cornerRadius: resolvedCornerRadius))
                }
                .beansCardShadow(radius: 9, y: 3)
            } else {
                content()
                    .padding(resolvedPadding)
                    .background(RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous).fill(.ultraThinMaterial))
                    .clipShape(RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous))
                    .beansCardShadow(radius: 9, y: 3)
            }
        } else {
            content()
                .padding(resolvedPadding)
                .background {
                    RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous)
                        .fill(uiStyle == .compact ? Color.beansGlassFill.opacity(0.72) : Color.clear)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous))
                .beansCardShadow(radius: 9, y: 3)
        }
    }
}

// MARK: - 播放/暂停图标

struct PlayPauseMorphIcon: View {
    let isPlaying: Bool
    var size: CGFloat = 22

    private var progress: CGFloat { isPlaying ? 1 : 0 }

    var body: some View {
        ZStack {
            Image(systemName: "play.fill")
                .font(.system(size: size, weight: .semibold))
                .opacity(1 - progress)
                .scaleEffect(1 - progress * 0.18)
                .offset(x: progress * 5)
            HStack(spacing: max(3, size * 0.18)) {
                RoundedRectangle(cornerRadius: max(1.5, size * 0.08), style: .continuous)
                    .frame(width: max(4, size * 0.24), height: size * 0.86)
                RoundedRectangle(cornerRadius: max(1.5, size * 0.08), style: .continuous)
                    .frame(width: max(4, size * 0.24), height: size * 0.86)
            }
            .opacity(progress)
            .scaleEffect(0.82 + progress * 0.18)
            .offset(x: (1 - progress) * -5)
        }
        .frame(width: size + 6, height: size + 6)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isPlaying)
    }
}

// MARK: - 导航容器

struct BeansNavigationStack<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack { content() }
    }
}

extension View {
    func beansScrollIndicatorsHidden() -> some View {
        scrollIndicators(.hidden)
    }

    func beansScrollContentBackgroundHidden() -> some View {
        scrollContentBackground(.hidden)
    }
}

// MARK: - 程序化封面（DJ多多无封面图，用歌曲 ID 生成稳定渐变 + 迷你波形）

enum CoverArt {
    /// 由歌曲 ID 稳定推导的色相
    static func hue(seed: Int) -> Double {
        let mixed = abs(seed &* 2_654_435_761) % 3600
        return Double(mixed) / 3600.0
    }

    static func colors(seed: Int, colorScheme: ColorScheme = .dark) -> [Color] {
        let base = hue(seed: seed)
        let shift = 0.12 + Double(abs(seed) % 7) * 0.012
        let saturation = colorScheme == .dark ? 0.62 : 0.52
        let brightness = colorScheme == .dark ? 0.78 : 0.86
        return [
            Color(hue: base, saturation: saturation, brightness: brightness),
            Color(hue: (base + shift).truncatingRemainder(dividingBy: 1),
                  saturation: min(0.85, saturation + 0.12),
                  brightness: brightness * 0.72),
        ]
    }

    static func uiImage(seed: Int, size: CGFloat = 600) -> UIImage {
        let palette = colors(seed: seed, colorScheme: .dark)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor(palette[0]).cgColor, UIColor(palette[1]).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors,
                                         locations: [0, 1]) {
                cg.drawLinearGradient(gradient,
                                      start: .zero,
                                      end: CGPoint(x: size, y: size),
                                      options: [])
            }
            // 波形
            cg.setFillColor(UIColor.white.withAlphaComponent(0.28).cgColor)
            let bars = 9
            let barWidth = size * 0.035
            let gap = size * 0.022
            let total = CGFloat(bars) * barWidth + CGFloat(bars - 1) * gap
            var x = (size - total) / 2
            for index in 0..<bars {
                let phase = sin(Double(seed % 97) * 0.19 + Double(index) * 0.9)
                let height = size * (0.10 + 0.12 * abs(phase))
                let rect = CGRect(x: x, y: size * 0.74 - height / 2,
                                  width: barWidth, height: height)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: barWidth / 2)
                path.fill()
                x += barWidth + gap
            }
        }
    }
}

/// 歌曲封面：程序化渐变 + 波形，不再依赖不存在的封面接口。
struct SongCover: View {
    let seed: Int
    var size: CGFloat
    var cornerRadius: CGFloat = 12
    var showsWave = true
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = CoverArt.colors(seed: seed, colorScheme: colorScheme)
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay {
                if showsWave {
                    WaveformBadge(size: size, seed: seed)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 0.7)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct WaveformBadge: View {
    let size: CGFloat
    let seed: Int

    var body: some View {
        HStack(alignment: .center, spacing: max(1.5, size * 0.022)) {
            ForEach(0..<9, id: \.self) { index in
                let phase = sin(Double(abs(seed) % 97) * 0.19 + Double(index) * 0.9)
                Capsule()
                    .fill(.white.opacity(0.30))
                    .frame(width: max(2, size * 0.03),
                           height: size * (0.10 + 0.12 * abs(phase)))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 按钮

struct GlassIconButton: View {
    @EnvironmentObject private var theme: ThemeStore
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    let systemName: String
    var size: CGFloat = 44
    var active = false
    var forceLiquid = false
    let action: () -> Void

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    var body: some View {
        let _ = theme.accent
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * (isNativeClean ? 0.42 : 0.38), weight: .semibold))
                .foregroundStyle(active ? Color.beansAmber : (isNativeClean ? Color.primary : Color.beansLabel))
                .frame(width: size, height: size)
                .background {
                    if isNativeClean && !forceLiquid {
                        Circle().fill(active ? Color.beansAmber.opacity(0.12) : .clear)
                    } else {
                        BeansGlass(shape: Circle())
                    }
                }
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(GlassPressButtonStyle())
    }
}

struct GlassButton: View {
    @EnvironmentObject private var theme: ThemeStore
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    let title: String
    var systemName: String?
    var prominent = false
    let action: () -> Void

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    var body: some View {
        let _ = theme.accent
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemName {
                    Image(systemName: systemName)
                }
                Text(LocalizedStringKey(title))
            }
            .font(BeansFont.appFont(15, .semibold))
            .foregroundStyle(prominent ? Color.white : Color.beansLabel)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                if prominent {
                    ZStack {
                        BeansGlass(shape: Capsule(), forceLiquid: true)
                        Capsule().fill(Color.beansAmber.opacity(0.78))
                    }
                } else if isNativeClean {
                    Capsule().fill(Color.primary.opacity(0.055))
                } else {
                    Capsule().fill(.thinMaterial)
                }
            }
            .overlay {
                if isNativeClean && !prominent {
                    Capsule().strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.7)
                }
            }
            .clipShape(Capsule())
        }
        .buttonStyle(GlassPressButtonStyle())
    }
}

// MARK: - 区块标题

struct SectionHeader: View {
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    let title: String
    var trailing: String?
    var titleColor: Color = Color.beansLabel
    var trailingColor: Color = Color.beansComment
    var onTrailingTap: (() -> Void)?

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(BeansFont.appFont(isNativeClean ? 26 : 21, .bold))
                .foregroundStyle(titleColor)
            Spacer()
            if let trailing {
                Button {
                    onTrailingTap?()
                } label: {
                    HStack(spacing: 3) {
                        Text(LocalizedStringKey(trailing))
                            .font(BeansFont.appFont(13, .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(trailingColor)
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.9))
            }
        }
    }
}

// MARK: - 空态 / 错误 / 加载

struct EmptyStateView: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.beansComment)
            Text(LocalizedStringKey(text))
                .font(BeansFont.appFont(14))
                .foregroundStyle(Color.beansComment)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.beansComment)
            Text(message)
                .font(BeansFont.appFont(14))
                .foregroundStyle(Color.beansComment)
                .multilineTextAlignment(.center)
            GlassButton(title: "重试", systemName: "arrow.clockwise", action: retry)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct LoadingStateView: View {
    @EnvironmentObject private var theme: ThemeStore

    var body: some View {
        let _ = theme.accent
        ProgressView()
            .controlSize(.large)
            .tint(Color.beansAmber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}

// MARK: - 当前播放指示

struct NowPlayingIndicator: View {
    @EnvironmentObject private var theme: ThemeStore
    @State private var animating = false

    var body: some View {
        let _ = theme.accent
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.beansAmber)
                    .frame(width: 3, height: animating ? 14 : 5)
                    .animation(
                        .easeInOut(duration: 0.35)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.12),
                        value: animating
                    )
            }
        }
        .frame(height: 16)
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

// MARK: - 播放进度线（迷你播放器用）

struct ProgressLine: View {
    @EnvironmentObject private var theme: ThemeStore
    let progress: Double
    let duration: Double

    private var ratio: Double {
        guard duration > 0.001 else { return 0 }
        return min(max(progress / duration, 0), 1)
    }

    var body: some View {
        let _ = theme.accent
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.beansComment.opacity(0.25))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.beansAmber, Color.beansAmber.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.width * ratio, 6))
            }
        }
        .frame(height: 3)
    }
}

// MARK: - 板块进入动画

struct SectionEntrance: ViewModifier {
    @State private var appeared = false
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func sectionEntrance(delay: Double = 0) -> some View {
        modifier(SectionEntrance(delay: delay))
    }
}

// MARK: - 全局轻提示

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    @Published var message: String?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ text: String, duration: Double = 2.2) {
        dismissTask?.cancel()
        message = text
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}

struct ToastView: View {
    @ObservedObject var center: ToastCenter
    @EnvironmentObject private var theme: ThemeStore

    var body: some View {
        let _ = theme.accent
        Text(center.message ?? "")
            .font(BeansFont.appFont(14, .medium))
            .foregroundStyle(Color.beansLabel)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                    }
            }
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            .padding(.horizontal, 30)
            .padding(.bottom, 92)
            .opacity(center.message == nil ? 0 : 1)
            .offset(y: center.message == nil ? 16 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: center.message)
            .allowsHitTesting(false)
    }
}

// MARK: - 弹窗尺寸

enum BeansDetent {
    case medium
    case large
    case fraction(CGFloat)
    case height(CGFloat)
}

struct BeansSheetModifier: ViewModifier {
    let detents: [BeansDetent]
    var dragIndicator: Bool?

    private func makeDetents() -> Set<PresentationDetent> {
        var result: Set<PresentationDetent> = []
        for detent in detents {
            switch detent {
            case .medium: result.insert(.medium)
            case .large: result.insert(.large)
            case .fraction(let f): result.insert(.fraction(f))
            case .height(let h): result.insert(.height(h))
            }
        }
        return result
    }

    func body(content: Content) -> some View {
        if let dragIndicator {
            content
                .presentationDetents(makeDetents())
                .presentationDragIndicator(dragIndicator ? .visible : .hidden)
        } else {
            content.presentationDetents(makeDetents())
        }
    }
}

// MARK: - 分享

struct ShareFileItem: Identifiable {
    let url: URL
    var id: String { url.path }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}