import SwiftUI
import UIKit

// MARK: - 底部 Tab

enum RootTab: String, CaseIterable, Identifiable {
    case discover
    case library
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: return "主页"
        case .library: return "音乐库"
        case .profile: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .discover: return "house.fill"
        case .library: return "music.note.list"
        case .profile: return "person.crop.circle"
        }
    }
}

// MARK: - 根视图

struct RootView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var favorites: FavoritesStore

    @AppStorage("beans.themeMode") private var themeModeRaw = BeansThemeMode.system.rawValue
    @AppStorage("beans.disclaimerAccepted") private var disclaimerAccepted = false

    @State private var selection: RootTab = .discover
    @State private var showPlayer = false
    @State private var showWhatsNew = false

    private var themeMode: BeansThemeMode {
        BeansThemeMode(rawValue: themeModeRaw) ?? .system
    }

    var body: some View {
        TabView(selection: $selection) {
            tabContent(DiscoverView())
                .tabItem { Label("主页", systemImage: RootTab.discover.icon) }
                .tag(RootTab.discover)
            tabContent(LibraryView())
                .tabItem { Label("音乐库", systemImage: RootTab.library.icon) }
                .tag(RootTab.library)
            tabContent(ProfileView())
                .tabItem { Label("我的", systemImage: RootTab.profile.icon) }
                .tag(RootTab.profile)
        }
        .tint(Color.beansAmber)
        .background {
            TabBarAppearanceConfigurator()
        }
        .preferredColorScheme(themeMode.colorScheme)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: player.currentSong?.id)
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(isPresented: $showPlayer)
                .environmentObject(player)
                .environmentObject(player.clock)
                .environmentObject(theme)
                .environmentObject(favorites)
        }
        .overlay(alignment: .top) {
            // 状态栏统一背景：与分类栏同一材质，避免只显示 tab 栏一层造成割裂
            StatusBarBackdrop()
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            ToastView(center: ToastCenter.shared)
        }
        .onAppear {
            CrashReporter.shared.markLaunchCompleted()
            if disclaimerAccepted, ChangelogStore.shouldShowWhatsNew {
                showWhatsNew = true
            }
            HighRefreshKeeper.shared.configure(enabled: true)
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewSheet()
        }
    }

    /// 每个 Tab 内容都留出迷你播放器的安全区，保证它浮在系统底栏之上。
    /// 容器背景吸收所有点击，避免点到播放条时穿透到底层歌曲卡片。
    private func tabContent<Content: View>(_ content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if player.currentSong != nil {
                ZStack {
                    // 不透明拦截层：填补播放条两侧与间隙，吞掉原本会落到列表上的点击
                    Rectangle()
                        .fill(Color.beansGlassFill.opacity(0.001))
                        .contentShape(Rectangle())
                        .onTapGesture { BeansHaptics.tap() }
                    MiniPlayerView(showPlayer: $showPlayer)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                }
                .frame(height: 76)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

// MARK: - 状态栏统一背景
// 覆盖状态栏区域，材质与分类栏保持一致，滚动时顶部不再出现只有 tab 栏一层的割裂感。

private struct StatusBarBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(width: geo.size.width, height: geo.safeAreaInsets.top)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.beansComment.opacity(0.10))
                        .frame(height: 0.5)
                }
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - 系统 TabBar 清透外观

struct TabBarAppearanceConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            Self.apply(from: controller)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            Self.apply(from: uiViewController)
        }
    }

    private static func apply(from controller: UIViewController) {
        guard let tabBar = controller.tabBarController?.tabBar else { return }
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = UIColor.beansAmber
        tabBar.isTranslucent = true
    }
}