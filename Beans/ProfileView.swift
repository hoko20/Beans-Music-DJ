import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

// MARK: - 我的

struct ProfileView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var favorites = FavoritesStore.shared
    @ObservedObject private var downloads = DownloadStore.shared
    @ObservedObject private var library = LocalLibraryStore.shared
    @ObservedObject private var equalizer = BeansEqualizer.shared

    @State private var showQueue = false
    @State private var showSleep = false
    @State private var showChangelog = false
    @State private var showLogs = false
    @State private var showDisclaimer = false
    @State private var cacheText = "计算中…"
    @AppStorage(DJddQuality.downloadKey) private var downloadQualityRaw = DJddQuality.high.rawValue
    @AppStorage("beans.themeMode") private var themeModeRaw = BeansThemeMode.system.rawValue

    private var downloadQuality: DJddQuality {
        DJddQuality(rawValue: downloadQualityRaw) ?? .high
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("我的")
                            .font(BeansFont.appFont(30, .bold))
                            .foregroundStyle(Color.beansLabel)
                            .padding(.top, 8)

                        localDataCard
                        quickGrid
                        settingsCard
                        Text("数据全部保存在本机，不采集任何个人信息")
                            .font(BeansFont.appFont(10))
                            .foregroundStyle(Color.beansComment)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 16)
                    // 为常驻迷你播放条留出充足空间，底部信息不再被遮挡
                    .padding(.bottom, 92)
                }
                .beansScrollIndicatorsHidden()
            }
        }
        .sheet(isPresented: $showQueue) { QueueView() }
        .sheet(isPresented: $showSleep) { SleepTimerSheet() }
        .sheet(isPresented: $showChangelog) { ChangelogListView() }
        .sheet(isPresented: $showLogs) { LogViewerSheet(importedText: nil) }
        .sheet(isPresented: $showDisclaimer) { DisclaimerSheet() }
        .task { cacheText = Self.cacheDescription() }
    }

    // MARK: 本机数据

    private var localDataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("本机数据")
                    .font(BeansFont.appFont(15, .bold))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                Button {
                    BeansHaptics.tap()
                    Self.clearCache()
                    cacheText = Self.cacheDescription()
                    ToastCenter.shared.show("缓存已清理")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("清理缓存 \(cacheText)")
                    }
                    .font(BeansFont.appFont(11, .medium))
                    .foregroundStyle(Color.beansComment)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 0) {
                stat(value: "\(favorites.djduoduoFavoriteSongs.count)", title: "收藏")
                divider
                stat(value: "\(downloads.tracks.count)", title: "下载")
                divider
                stat(value: "\(library.playlists.count)", title: "歌单")
            }
        }
        .padding(16)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.beansComment.opacity(0.18))
            .frame(width: 0.7, height: 28)
    }

    private func stat(value: String, title: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(BeansFont.appFont(20, .bold, .rounded))
                .foregroundStyle(Color.beansLabel)
            Text(title)
                .font(BeansFont.appFont(10))
                .foregroundStyle(Color.beansComment)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 六宫格

    private var quickGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                  spacing: 12) {
            NavigationLink { EqualizerSettingsView() } label: {
                tile(icon: "slider.horizontal.3",
                     tint: Color(red: 0.96, green: 0.62, blue: 0.32),
                     title: "均衡器",
                     detail: equalizer.isEnabled ? equalizer.selectedPreset.displayName : "已关闭")
            }
            .buttonStyle(.plain)

            Button { showQueue = true } label: {
                tile(icon: "list.bullet",
                     tint: Color(red: 0.39, green: 0.71, blue: 0.96),
                     title: "播放队列",
                     detail: "\(player.queue.count) 首")
            }
            .buttonStyle(.plain)

            Button { showSleep = true } label: {
                tile(icon: "moon.zzz.fill",
                     tint: Color(red: 0.55, green: 0.52, blue: 0.92),
                     title: "睡眠定时",
                     detail: player.sleepTimerFormatted ?? "已关闭")
            }
            .buttonStyle(.plain)

            NavigationLink { AppearanceSettingsView() } label: {
                tile(icon: "paintpalette.fill",
                     tint: Color.beansAmber,
                     title: "外观",
                     detail: theme.accent.rawValue)
            }
            .buttonStyle(.plain)

            NavigationLink { BackupCenterView() } label: {
                tile(icon: "externaldrive.badge.timemachine",
                     tint: Color.beansSage,
                     title: "备份恢复",
                     detail: "JSON")
            }
            .buttonStyle(.plain)

            Button { showChangelog = true } label: {
                tile(icon: "sparkles",
                     tint: Color(red: 0.93, green: 0.35, blue: 0.45),
                     title: "关于",
                     detail: "v\(appVersion)")
            }
            .buttonStyle(.plain)
        }
    }

    private func tile(icon: String, tint: Color, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(BeansFont.appFont(13, .semibold))
                .foregroundStyle(Color.beansLabel)
            Text(detail)
                .font(BeansFont.appFont(10))
                .foregroundStyle(Color.beansComment)
                .lineLimit(1)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 16, style: .continuous)) }
    }

    // MARK: 设置

    private var settingsCard: some View {
        VStack(spacing: 14) {
            settingsGroup(title: "播放") {
                qualityRow(icon: "waveform",
                           tint: Color.beansAmber,
                           title: "默认播放音质",
                           value: player.playbackQuality.title,
                           selection: player.playbackQuality) { quality in
                    player.playbackQuality = quality
                }
                rowDivider
                qualityRow(icon: "arrow.down.circle",
                           tint: Color.beansSage,
                           title: "下载音质",
                           value: downloadQuality.title,
                           selection: downloadQuality) { quality in
                    downloadQualityRaw = quality.rawValue
                }
            }

            settingsGroup(title: "外观") {
                Menu {
                    ForEach(BeansUIStyle.allCases, id: \.self) { style in
                        Button {
                            theme.setUIStyle(style)
                        } label: {
                            if style == theme.uiStyle {
                                Label(style.title, systemImage: "checkmark")
                            } else {
                                Text(style.title)
                            }
                        }
                    }
                } label: {
                    settingRow(icon: "square.on.circle",
                               tint: Color(red: 0.39, green: 0.71, blue: 0.96),
                               title: "界面风格",
                               value: theme.uiStyle.title)
                }
                rowDivider
                Menu {
                    ForEach(BeansThemeMode.allCases) { mode in
                        Button {
                            themeModeRaw = mode.rawValue
                        } label: {
                            if mode == currentThemeMode {
                                Label(mode.title, systemImage: "checkmark")
                            } else {
                                Text(mode.title)
                            }
                        }
                    }
                } label: {
                    settingRow(icon: "circle.lefthalf.filled",
                               tint: Color(red: 0.55, green: 0.52, blue: 0.92),
                               title: "深浅模式",
                               value: currentThemeMode.title)
                }
            }

            settingsGroup(title: "其他") {
                Button { showChangelog = true } label: {
                    settingRow(icon: "sparkles",
                               tint: Color.beansAmber,
                               title: "更新日志",
                               value: "v\(appVersion)")
                }
                .buttonStyle(.plain)
                rowDivider
                Button { showLogs = true } label: {
                    settingRow(icon: "doc.text",
                               tint: Color.beansComment,
                               title: "运行日志",
                               value: "查看")
                }
                .buttonStyle(.plain)
                rowDivider
                Button { showDisclaimer = true } label: {
                    settingRow(icon: "shield.lefthalf.filled",
                               tint: Color.beansSage,
                               title: "免责声明",
                               value: "查看")
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("豆豆音乐 \(appVersion)")
            }
            .font(BeansFont.appFont(11))
            .foregroundStyle(Color.beansComment)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
    }

    private var currentThemeMode: BeansThemeMode {
        BeansThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.beansComment.opacity(0.10))
            .frame(height: 0.7)
            .padding(.leading, 41)
    }

    private func settingsGroup<Content: View>(title: String,
                                              @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(BeansFont.appFont(12, .semibold))
                .foregroundStyle(Color.beansComment)
                .padding(.leading, 8)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
        }
    }

    private func settingRow(icon: String, tint: Color, title: String, value: String,
                            showsChevron: Bool = true) -> some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(0.16))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }
            Text(title)
                .font(BeansFont.appFont(14))
                .foregroundStyle(Color.beansLabel)
            Spacer(minLength: 8)
            Text(value)
                .font(BeansFont.appFont(12))
                .foregroundStyle(Color.beansComment)
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.beansComment.opacity(0.6))
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func qualityRow(icon: String, tint: Color, title: String, value: String,
                            selection: DJddQuality,
                            onSelect: @escaping (DJddQuality) -> Void) -> some View {
        Menu {
            ForEach(DJddQuality.allCases) { quality in
                Button {
                    onSelect(quality)
                    ToastCenter.shared.show("\(title)：\(quality.title)")
                } label: {
                    if quality == selection {
                        Label("\(quality.title) · \(quality.summary)", systemImage: "checkmark")
                    } else {
                        Text("\(quality.title) · \(quality.summary)")
                    }
                }
            }
        } label: {
            settingRow(icon: icon, tint: tint, title: title, value: value)
        }
    }

    // MARK: 缓存

    static func cacheDescription() -> String {
        let size = cacheBytes()
        return DownloadStore.formattedBytes(size)
    }

    private static func cacheBytes() -> Int64 {
        var total: Int64 = 0
        let urls = [
            FileManager.default.temporaryDirectory,
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0],
        ]
        for url in urls {
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let file as URL in enumerator {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                total += Int64(size)
            }
        }
        return total
    }

    private static func clearCache() {
        let fm = FileManager.default
        try? URLCache.shared.removeAllCachedResponses()
        for url in [fm.temporaryDirectory,
                    fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]] {
            guard let contents = try? fm.contentsOfDirectory(at: url,
                                                             includingPropertiesForKeys: nil) else { continue }
            for file in contents {
                try? fm.removeItem(at: file)
            }
        }
    }
}

// MARK: - 免责声明

struct DisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("· 本应用只用于个人学习与研究，禁止商业及非法用途。")
                    Text("· 歌曲、分类、音质均来自 DJ多多公开接口，本应用不存储、不传播任何音频内容。")
                    Text("· 音乐版权归各平台与权利人所有，请支持正版。")
                    Text("· 收藏、歌单、下载均保存在本机，卸载后会一并删除。")
                }
                .font(BeansFont.appFont(13))
                .foregroundStyle(Color.beansLabel)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle("免责声明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 均衡器

struct EqualizerSettingsView: View {
    @ObservedObject private var equalizer = BeansEqualizer.shared

    var body: some View {
        ZStack {
            GlassBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Toggle(isOn: Binding(
                        get: { equalizer.isEnabled },
                        set: { equalizer.setEnabled($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("启用均衡器")
                                .font(BeansFont.appFont(15, .semibold))
                                .foregroundStyle(Color.beansLabel)
                            Text("通过音频处理 tap 实时生效")
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(Color.beansComment)
                        }
                    }
                    .tint(Color.beansAmber)

                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(BeansEqualizerPreset.allCases) { preset in
                                Button {
                                    equalizer.applyPreset(preset)
                                } label: {
                                    Text(preset.displayName)
                                        .font(BeansFont.appFont(12, .medium))
                                        .foregroundStyle(equalizer.selectedPreset == preset ? .white : Color.beansLabel)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background {
                                            if equalizer.selectedPreset == preset {
                                                Capsule().fill(LinearGradient.beansAccent)
                                            } else {
                                                BeansGlass(shape: Capsule())
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    VStack(spacing: 10) {
                        ForEach(Array(BeansEqualizer.bandFrequencies.enumerated()), id: \.offset) { index, frequency in
                            HStack(spacing: 12) {
                                Text(formatFrequency(frequency))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.beansComment)
                                    .frame(width: 46, alignment: .leading)
                                Slider(
                                    value: Binding(
                                        get: { equalizer.bandGains[index] },
                                        set: { equalizer.setBandGain(at: index, to: $0) }
                                    ),
                                    in: -BeansEqualizer.maximumGain...BeansEqualizer.maximumGain,
                                    step: 0.5
                                )
                                .tint(Color.beansAmber)
                                Text(String(format: "%+.1f", equalizer.bandGains[index]))
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.beansComment)
                                    .frame(width: 38, alignment: .trailing)
                            }
                        }
                    }
                    .padding(14)
                    .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }

                    Button {
                        equalizer.reset()
                        ToastCenter.shared.show("已恢复默认")
                    } label: {
                        Text("恢复默认")
                            .font(BeansFont.appFont(14, .semibold))
                            .foregroundStyle(Color.beansLabel)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .beansScrollIndicatorsHidden()
        }
        .navigationTitle("均衡器")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatFrequency(_ value: Double) -> String {
        value >= 1000 ? String(format: "%.0fk", value / 1000) : "\(Int(value))"
    }
}

// MARK: - 外观

struct AppearanceSettingsView: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("beans.themeMode") private var themeModeRaw = BeansThemeMode.system.rawValue
    @State private var pickedItem: PhotosPickerItem?
    @State private var isImporting = false

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    /// 当前外观下真正生效的壁纸（另一侧为空时会回退，这里读到的是回退后的路径）
    private var currentWallpaperPath: String {
        theme.backgroundImagePath(for: colorScheme)
    }

    var body: some View {
        ZStack {
            // 预览页恒定展示当前壁纸：即使关闭“同步到所有页面”，这里也要立刻看到效果
            GlassBackdrop(homeMode: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("深浅模式")
                            .font(BeansFont.appFont(14, .semibold))
                            .foregroundStyle(Color.beansLabel)
                        Picker("深浅模式", selection: $themeModeRaw) {
                            ForEach(BeansThemeMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("主题配色")
                            .font(BeansFont.appFont(14, .semibold))
                            .foregroundStyle(Color.beansLabel)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(BeansAccent.allCases) { accent in
                                Button {
                                    BeansHaptics.select()
                                    theme.set(accent)
                                } label: {
                                    VStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(LinearGradient(colors: accent.gradientColors,
                                                                 startPoint: .topLeading,
                                                                 endPoint: .bottomTrailing))
                                            .frame(height: 52)
                                            .overlay {
                                                if theme.accent == accent {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(.white)
                                                        .font(.system(size: 18, weight: .bold))
                                                }
                                            }
                                        Text(accent.rawValue)
                                            .font(BeansFont.appFont(11, .medium))
                                            .foregroundStyle(Color.beansLabel)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    wallpaperCard
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .beansScrollIndicatorsHidden()
        }
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickedItem) { _, item in
            importWallpaper(from: item)
        }
    }

    // MARK: 壁纸

    private var wallpaperCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("壁纸")
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                Text(colorScheme == .dark ? "深色模式" : "浅色模式")
                    .font(BeansFont.appFont(10, .medium))
                    .foregroundStyle(Color.beansComment)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background { BeansGlass(shape: Capsule()) }
            }

            wallpaperPreview

            HStack(spacing: 10) {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    HStack(spacing: 6) {
                        if isImporting {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(Color.beansLabel)
                        } else {
                            Image(systemName: "photo")
                        }
                        Text(isImporting ? "导入中…" : "导入壁纸")
                    }
                    .font(BeansFont.appFont(13, .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background { BeansGlass(shape: Capsule()) }
                }
                .disabled(isImporting)

                Button {
                    BeansHaptics.tap()
                    theme.clearBackgroundImage(for: colorScheme)
                    ToastCenter.shared.show("已移除壁纸")
                } label: {
                    Text("移除")
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(currentWallpaperPath.isEmpty ? Color.beansComment.opacity(0.45) : Color.beansComment)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background { BeansGlass(shape: Capsule()) }
                }
                .buttonStyle(.plain)
                .disabled(currentWallpaperPath.isEmpty)
                Spacer()
            }

            if theme.wallpaperPaths.isEmpty {
                Text("导入后的壁纸会保存在这里，可随时切换")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(theme.wallpaperPaths, id: \.self) { path in
                            Button {
                                BeansHaptics.select()
                                theme.applyWallpaper(at: path, for: colorScheme)
                                ToastCenter.shared.show("已切换壁纸")
                            } label: {
                                wallpaperThumbnail(path)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    theme.deleteWallpaper(at: path)
                                    ToastCenter.shared.show("已删除壁纸")
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
            }

            Toggle("壁纸同步到所有页面", isOn: Binding(
                get: { theme.backgroundSyncAll },
                set: { theme.setBackgroundSyncAll($0) }
            ))
            .font(BeansFont.appFont(13))
            .tint(Color.beansAmber)
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
    }

    private var wallpaperPreview: some View {
        ZStack {
            LinearGradient.beansBackdrop
            if let image = theme.customBackgroundImage(for: colorScheme) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 168)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 24, weight: .semibold))
                    Text("还没有设置壁纸")
                        .font(BeansFont.appFont(12, .semibold))
                    Text("点“导入壁纸”从相册选一张照片")
                        .font(BeansFont.appFont(10))
                }
                .foregroundStyle(Color.beansComment)
            }
        }
        .frame(height: 168)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.beansComment.opacity(0.16), lineWidth: 1)
        }
    }

    private func wallpaperThumbnail(_ path: String) -> some View {
        let selected = currentWallpaperPath == path
        return ZStack {
            Color.beansGlassFill
            if let image = BeansImageFileCache.image(at: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(Color.beansComment)
            }
        }
        .frame(width: 62, height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? Color.beansAmber : Color.beansComment.opacity(0.16),
                              lineWidth: selected ? 2 : 1)
        }
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.beansAmber)
                    .background(Circle().fill(Color.black.opacity(0.28)))
                    .offset(x: 3, y: -3)
            }
        }
    }

    /// 相册选择回调：先取数据再落盘，失败给出明确提示，不再出现“看起来导入成功但没反应”。
    private func importWallpaper(from item: PhotosPickerItem?) {
        guard let item, !isImporting else { return }
        isImporting = true
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            await MainActor.run {
                isImporting = false
                // 复位选择：同一张照片再次选择时也要能重新触发
                pickedItem = nil
                guard let data, !data.isEmpty else {
                    ToastCenter.shared.show("无法读取这张图片，请换一张重试")
                    return
                }
                if theme.addWallpaper(data, for: colorScheme) {
                    BeansHaptics.success()
                    ToastCenter.shared.show("壁纸已应用")
                } else {
                    ToastCenter.shared.show("壁纸保存失败，请重试")
                }
            }
        }
    }
}

// MARK: - 备份恢复

struct BackupPayload: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var favorites: [Song] = []
    var playlists: [LocalPlaylist] = []
    var history: [Song] = []
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupCenterView: View {
    @ObservedObject private var favorites = FavoritesStore.shared
    @ObservedObject private var library = LocalLibraryStore.shared
    @EnvironmentObject private var player: PlayerManager

    @State private var exportDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var message: String?

    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 14) {
                Text("把收藏、歌单、最近播放与设置导出为 JSON；换机或重装后导入即可恢复。")
                    .font(BeansFont.appFont(13))
                    .foregroundStyle(Color.beansComment)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                GlassButton(title: "导出备份", systemName: "square.and.arrow.up") {
                    exportDocument = BackupDocument(data: makeBackupData())
                    showExporter = true
                }
                GlassButton(title: "导入备份", systemName: "square.and.arrow.down") {
                    showImporter = true
                }
                if let message {
                    Text(message)
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansSage)
                }
                Spacer()
            }
            .padding(.top, 24)
        }
        .navigationTitle("备份恢复")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $showExporter,
                      document: exportDocument,
                      contentType: .json,
                      defaultFilename: "BeansMusicBackup") { result in
            switch result {
            case .success: message = "备份已导出"
            case .failure(let error): message = "导出失败：\(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importBackup(from: url)
            case .failure(let error):
                message = "导入失败：\(error.localizedDescription)"
            }
        }
    }

    private func makeBackupData() -> Data {
        var payload = BackupPayload()
        payload.favorites = favorites.djduoduoFavoriteSongs
        payload.playlists = library.playlists
        payload.history = player.history
        return (try? JSONEncoder().encode(payload)) ?? Data()
    }

    private func importBackup(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(BackupPayload.self, from: data) else {
            message = "文件格式不正确"
            return
        }
        favorites.replaceAll(payload.favorites)
        library.replaceAll(payload.playlists)
        player.restoreHistory(payload.history)
        message = "已恢复：收藏 \(payload.favorites.count) 首 · 歌单 \(payload.playlists.count) 个"
        ToastCenter.shared.show("备份已恢复")
    }
}