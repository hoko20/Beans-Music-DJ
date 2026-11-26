import SwiftUI
import UIKit

@main
struct BeansApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var player = PlayerManager()
    @StateObject private var theme = ThemeStore.shared
    @StateObject private var favorites = FavoritesStore.shared
    /// 免责声明确认状态：未确认前主界面在引导页下方可见，确认后移除门禁
    @AppStorage("beans.disclaimerAccepted") private var disclaimerAccepted = false

    init() {
        // 闪退检测：优先初始化，检测上次异常退出并安装崩溃捕获
        _ = CrashReporter.shared
        // 主页暂停只应在设置页打开期间生效，避免异常退出后把暂停状态永久写入本地。
        UserDefaults.standard.set(false, forKey: "beans.pauseHomeRendering")
        HighRefreshKeeper.registerDefaults()
        HighRefreshKeeper.shared.configureFromDefaults()
        UserDefaults.standard.register(defaults: [
            "beans.uiStyle": BeansUIStyle.nativeClean.rawValue,
            "beans.haptics.enabled": true,
            "beans.playback.autoResumeLast": false,
            "beans.playback.autoSkipOnFailure": true,
            "beans.homeWallpaperBlur": 0.0,
        ])
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(player)
                    .environmentObject(player.clock)
                    .environmentObject(theme)
                    .environmentObject(favorites)
                if !disclaimerAccepted {
                    OnboardingView { disclaimerAccepted = true }
                }
            }
            .tint(Color.beansAmber)
            .task {
                await Task.yield()
                player.restorePersistedPlayMode()
                player.resumePersistedPlaybackIfEnabled()
                FontManager.reinstallIfNeeded()
                theme.restoreWallpapersIfNeeded()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
            }
        }
    }
}