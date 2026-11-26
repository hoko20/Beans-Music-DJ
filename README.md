# Beans Music DJ

一个只接入 **DJ多多** 的 iOS 26 SwiftUI 音乐播放器。

基于开源 [XIaodou0416/Beans-Music](https://github.com/XIaodou0416/Beans-Music) 1.6.6 精简重构：
保留 Beans 的液态玻璃视觉、播放内核、下载、收藏与队列能力，删掉取不到数据的平台、账号与同步层，
只留一条链路：**看列表 → 播 → 存**。

- 仓库：https://github.com/hoko20/Beans-Music-DJ
- 构建产物：`Beans-unsigned.ipa`（未签名，需 AltStore / Sideloadly / 爱思自签安装）
- 系统要求：iOS 26.0+，仅 iPhone，仅中文

## 功能

- 15 个分类浏览与切换，列表上拉分页（30 首 / 页）
- 跨 6 个分类聚合的标题 / 上传者搜索
- 播放 / 暂停、上下首、进度拖动与快进快退、上下滑切歌
- 顺序 / 单曲 / 随机、倍速 0.5–2.0、睡眠定时
- 四档音质（流畅 80k / 标准 128k / 高品 320k / 无损 FLAC）播放与下载
- 下载中心：实时进度、体积统计、导出分享、删除；已下载自动离线播放
- 红心收藏、本地歌单、最近播放、播放队列
- 程序化封面（按歌曲 ID 生成渐变 + 波形）、封面主色联动、节奏光环
- 9 套主题色、深浅模式、壁纸导入、均衡器、备份恢复
- 后台播放、锁屏 / 控制中心控制、高刷新率保持

## 工程结构

```
Beans/
  BeansApp.swift       应用入口
  RootView.swift       3 Tab + 迷你播放器
  DiscoverView.swift   15 分类 + 双列卡片 + 分页
  SearchView.swift     搜索浮层（聚合 + 本地过滤）
  LibraryView.swift    红心 / 下载中心 / 历史 / 本地歌单
  ProfileView.swift    本机数据、均衡器、外观、备份、设置
  PlayerView.swift     播放页 + 音质面板
  PlayerManager.swift  播放内核、队列、历史、定时
  DJduoduoAPI.swift    DJ多多协议（加密 / 分类 / 列表 / 音质 / 下载）
  DownloadManager.swift 下载中心 DownloadStore
  Components.swift     液态玻璃组件、程序化封面、Toast
  Models.swift         DJddQuality / Song
  Theme.swift          主题、壁纸、配色
```

## 构建

需要 macOS、Xcode 26 或更新版本、XcodeGen：

```bash
brew install xcodegen
xcodegen generate
xcodebuild \
  -project Beans.xcodeproj \
  -scheme Beans \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build
```

GitHub Actions 工作流 `build-unsigned-ipa.yml` 可在 `macos-26` 上打包未签名 IPA。

## 免责声明

本应用仅供个人学习与研究，禁止商业及非法用途。歌曲、分类、音质均来自 DJ多多公开接口，
本应用不存储、不传播任何音频内容，音乐版权归各平台与权利人所有，请支持正版。

## License

MIT License，见 [LICENSE](LICENSE)。