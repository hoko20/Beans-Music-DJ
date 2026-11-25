# Beans Music + DJ多多平台接入说明

本项目基于开源 [XIaodou0416/Beans-Music](https://github.com/XIaodou0416/Beans-Music) 1.6.6，
新增第四个音乐平台「DJ多多」（逆向自 DJ多多 4.3.7），完整复用 Beans 现成的
SwiftUI 液态玻璃 UI、播放器、下载、歌词、收藏、队列等能力。

- 仓库：https://github.com/hoko20/Beans-Music-DJ
- 构建产物：`Beans-unsigned.ipa`（未签名，需 AltStore / Sideloadly / 爱思自签安装）
- 编译状态：GitHub Actions `macos-26` 已构建通过（run 45559370460）

---

## 怎么用

1. 发现页 / 搜索页顶部的平台选择器，切换到「DJ多多」（橙红渐变 + 波形图标）。
2. 发现页切到 DJ多多后，顶部出现 15 个分类横向选择器（最热/最新/电音/无损专区/车载/粤语/彩铃/儿歌/中文/外文/伤感/3D/DJ/铃声/老歌），点选即切换列表。
3. 搜索页支持歌曲名 / 作者本地过滤（服务端 search act 参数未破解）。
4. 点歌曲进入 Beans 原生播放页，支持播放/暂停、上一首下一首、进度拖动、后台播放、歌词面板。
5. 下载、红心收藏均可正常使用，收藏本地持久化（无云端接口）。

---

## 接入改动清单

| 文件 | 改动 |
|---|---|
| `Beans/DJduoduoAPI.swift` | **新增**。DJddCrypto（MD5/AES-CBC/URL 编码/Path 解密）+ DJddCategory + 单例 API（分类/列表/下载/封面/搜索） |
| `Beans/Models.swift` | `SongSource` 加 `.djduoduo`；`Song` 加 `djduoduoPath` / `djduoduoUserId` 字段（含 Codable）；音质档位、`identityKey`、`isVIP` 补 case |
| `Beans/SearchView.swift` | `SearchProvider` 加 case + 主题色/图标；搜索 12 分支 switch、专辑兜底、热搜词分派补 DJdd |
| `Beans/LibraryView.swift` | `LibraryProvider` 加 case；新增 `djduoduoSection` 显示本地红心歌曲 |
| `Beans/PlayerManager.swift` | `loadCurrent()` 加 DJdd 播放 URL 分支；第三方音源/会员判断补 case |
| `Beans/DownloadManager.swift` | `resolveURL()` 加 DJdd 下载 URL 分支 |
| `Beans/FavoritesStore.swift` | 新增 DJdd 本地红心数组与持久化 |
| `Beans/DiscoverView.swift` | 首页 load switch 加 DJdd 推荐流；排行榜/歌单文案补 case |
| 其余 8 个文件 | `Language` / `PlatformPreferenceStore` / `PlayerView` / `PlaylistView` / `ProfileView` / `UnblockService` / `LocalMusicSection` / `LXScriptSourceRunner` 补 switch 穷举 |

`project.yml` 的 `sources: [Beans]` 自动纳入新 `.swift`，无需手动登记；ATS 已 `NSAllowsArbitraryLoads: true`，
DJdd CDN 是 `http://bdcdn.djduoduo.com`，可直接播放/下载。

---

## DJ多多 API 协议（已实测）

```
基址  https://api.dianyinduoduo.com/v4/getlist.php
参数  ?act=<动作>&data=<base64(AES)>&extra=<base64(AES)>

分类  act=listtab   data={"PageNo":0,"type":"home"} → 首页 15 项
      不带 type / type="ring"                      → 彩铃 tab 仅 3 项（112/115/116）
列表  act=<分类Act> data={"PageNo":p,"Id":分类Id}  → RetCode=200 Count=30
      最热/最新/无损专区 id=0 → 只传 act=hot/new/sq，不带 Id
音质  act=formats   data={"Id":歌曲Id,"Uid":登录Uid,
                          "OpenId":登录OpenId,"Status":状态}
      响应 Formats[]：Quality / Size / Bitrate / Path(加密，同媒体 key)
      档位 0 流畅 / 1 标准 / 2 高品 / 3 无损；MaxQ = 可用档位数
下载  CDN/dj/{Id%1000补3位}/{Path解密文件名}      → 206 + ftyp mp42
封面  CDN/v/cover/{Id%1000补3位}/{UserId}/{Cover}

AES   AES-128-CBC + PKCS7
      key = MD5("slf2yoDUOr3diocu")  iv = MD5("2mhamCk1helsrT")   (data/extra)
      key = MD5("sdf2goDUOdjumogu")  iv = MD5("2ghlmCl1hblsqT")   (Path→文件名)
      明文 NSJSONSerialization(prettyPrinted) 风格；base64 后 + / = 全部 %XX
      ★ 不缓存 Sign：列表接口带 Sign 会返回 403「请升级」
```

### 已知限制

- **搜索**：服务端 `act=search` 参数未破解，用前 4 个分类列表本地过滤兜底。
- **音质选择**：`formats` 协议已按反汇编完整实现（`DJduoduoAPI.formats()`），
  但 `Uid/OpenId` 来自 App 登录态，未登录直连一律返回 `RetCode=401`，
  因此尚未接入下载/播放器的档位切换 UI；登录态拿到后即可启用。
- **歌词**：服务端 `act=lyric` 是独立第五套密钥，已按需求停止分析；Beans 自带本地 LRC 解析能力保留，DJdd 歌曲无在线歌词。
- **排行榜 / 云端歌单**：DJdd 无对应接口，相关区域显示为空或本地红心。
- **收藏**：本地持久化（`beans.fav.djduoduo.v1`），无云端同步。
- **未真机验证**：Windows 无 Xcode / iOS 设备，仅完成 CI 编译与 IPA 打包。
