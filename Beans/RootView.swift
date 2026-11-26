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
            ChangelogListView()
        }
    }

    /// 每个 Tab 内容都留出迷你播放器的安全区，保证它浮在系统底栏之上。
    private func tabContent<Content: View>(_ content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if player.currentSong != nil {
                MiniPlayerView(showPlayer: $showPlayer)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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