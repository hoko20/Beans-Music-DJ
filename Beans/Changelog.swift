import SwiftUI

// MARK: - 版本更新日志（设置页与首次更新弹窗使用）

struct VersionLog: Identifiable {
    let id: String
    let version: String
    let title: String
    let notices: [String]
    let features: [String]
    let fixes: [String]
    let imageURL: URL?
    let textColorHex: String?

    init(id: String, version: String, title: String, notices: [String] = [], features: [String], fixes: [String] = [], imageURL: URL? = nil, textColorHex: String? = nil) {
        self.id = id
        self.version = version
        self.title = title
        self.notices = notices
        self.features = features
        self.fixes = fixes
        self.imageURL = imageURL
        self.textColorHex = textColorHex
    }
}

enum ChangelogStore {
    static let lastSeenKey = "beans.lastSeenVersion"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var lastSeenVersion: String {
        UserDefaults.standard.string(forKey: lastSeenKey) ?? ""
    }

    static func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: lastSeenKey)
        UserDefaults.standard.synchronize()
    }

    static var shouldShowWhatsNew: Bool {
        lastSeenVersion != currentVersion
    }

    static var latest: VersionLog? { logs.first }

    static let logs: [VersionLog] = [
        VersionLog(
            id: "2.0.4",
            version: "2.0.4",
            title: "更干净的点击，更轻的内存",
            notices: [
                "应用标识已改为 com.doudou.music，本次是独立安装：旧版本的数据不会自动迁移，建议先在旧版「备份恢复」里导出 JSON 再导入。"
            ],
            features: [
                "播放、外观两组设置项点击时不再出现长方形的系统高亮条框",
                "壁纸条改用降采样缩略图，图库再多也不会把大图全塞进内存",
                "图片与锁屏封面缓存加上容量上限，长时间浏览不再越用越占内存",
                "壁纸 base64 备份只保留当前与最近几张，设置文件不再膨胀到几 MB",
                "清理不再使用的壁纸备份、清空等死代码，保持代码精简"
            ]
        ),
    ]
}

// MARK: - 更新说明弹窗

struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: ThemeStore.shared.backgroundSyncAll ? ThemeStore.shared.customBackground : nil)
                ScrollView {
                    if let log = ChangelogStore.latest {
                        VersionLogCard(log: log)
                            .padding(16)
                    }
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("更新说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始使用") {
                        ChangelogStore.markSeen()
                        dismiss()
                    }
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansAmber)
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large]))
        .onDisappear {
            ChangelogStore.markSeen()
        }
    }
}

struct ChangelogListView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: ThemeStore.shared.backgroundSyncAll ? ThemeStore.shared.customBackground : nil)
                ScrollView {
                    if let log = ChangelogStore.latest {
                        VersionLogCard(log: log)
                            .padding(16)
                    }
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("更新说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large]))
    }
}

private struct VersionLogCard: View {
    let log: VersionLog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("v\(log.version)")
                    .font(BeansFont.appFont(16, .bold))
                    .foregroundStyle(Color.beansAmber)
                Text(log.title)
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(textColor)
            }
            if let imageURL = log.imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else if phase.error != nil {
                        EmptyView()
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 80)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !log.notices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(log.notices, id: \.self) { notice in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.top, 1)
                            Text(notice)
                                .font(BeansFont.appFont(13, .semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.red.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            if !log.features.isEmpty {
                logSection(title: "新增功能", icon: "plus.circle.fill", items: log.features)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .beansCardShadow(radius: 9, y: 3)
    }

    private func logSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(BeansFont.appFont(14, .bold))
                .foregroundStyle(Color.beansAmber)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansAmber)
                        .padding(.top, 2)
                    Text(LocalizedStringKey(item))
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var textColor: Color {
        if let raw = log.textColorHex, let color = Color(hex: raw) { return color }
        return Color.beansLabel
    }
}
