# Beans Music DJ + DJ多多平台接入说明

本项目基于开源 [XIaodou0416/Beans-Music](https://github.com/XIaodou0416/Beans-Music) 1.6.6，
在 2.0.0 中收敛为 **DJ多多单平台** 播放器（逆向自 DJ多多 4.3.7），完整复用 Beans 的
SwiftUI 液态玻璃 UI、播放器、下载、收藏、队列等能力。

- 仓库：https://github.com/hoko20/Beans-Music-DJ
- 构建产物：`Beans-unsigned.ipa`（未签名，需 AltStore / Sideloadly / 爱思自签安装）
- 系统要求：iOS 26.0+，仅 iPhone，仅中文

---

## 怎么用

1. 首次启动完成免责确认（输入「我已了解并同意」）。
2. 主页顶部是 15 个分类胶囊（最热/最新/电音/无损专区/车载/粤语/彩铃/儿歌/中文/外文/伤感/3D/DJ/铃声/老歌），
   点选即切换列表，双列卡片上拉自动加载下一页。
3. 点顶栏放大镜或搜索框进入搜索浮层：最近搜索、15 分类直达、跨 6 个分类聚合过滤。
4. 点卡片直接播放；长按卡片可下一首播放 / 收藏 / 下载。
5. 播放页点「音质」打开四档面板，可切换播放音质或下载对应档位。
6. 音乐库 → 已下载：查看进度、占用空间、导出分享、删除；已下载歌曲自动离线播放。

---

## 2.0.0 结构与取舍

| 保留 | 移除 |
|---|---|
| DJduoduoAPI（加密/分类/列表/音质/下载） | 网易云 / QQ / 酷狗 API 与三套鉴权 |
| 播放内核、队列、睡眠定时、均衡器 | 账号登录、扫码、网页登录、Cookie 导入 |
| 四档音质播放与下载、下载中心 | 云端歌单同步、每日推荐、排行榜、歌手页、评论 |
| 红心收藏、本地歌单、最近播放 | 在线歌词与歌词面板 |
| 9 套主题、壁纸、字体、备份恢复 | 第三方音源（解锁服务、LX 脚本） |
| 程序化封面、节奏光环、液态玻璃 | iOS 15–18 兼容分支、自绘底栏、英文语言包 |

主要文件：

| 文件 | 职责 |
|---|---|
| `Beans/DJduoduoAPI.swift` | DJddCrypto（MD5/AES-CBC/URL 编码/Path 解密）+ 分类 / 列表 / 音质 / 搜索 |
| `Beans/Models.swift` | `DJddQuality`（四档）、`Song`（含旧数据兼容解码） |
| `Beans/DownloadManager.swift` | `DownloadStore` 下载中心（进度、体积、导出、删除） |
| `Beans/PlayerManager.swift` | 本地优先播放、音质切换、队列、历史、定时 |
| `Beans/DiscoverView.swift` | 15 分类 + 双列卡片 + 分页 |
| `Beans/SearchView.swift` | 搜索浮层（聚合 6 分类 + 本地过滤） |
| `Beans/LibraryView.swift` | 红心 / 下载中心 / 历史 / 本地歌单 |
| `Beans/ProfileView.swift` | 本机数据、均衡器、外观、备份、设置 |
| `Beans/PlayerView.swift` | 播放页 + 音质与下载面板 |

`project.yml` 的 `sources: [Beans]` 自动纳入新 `.swift`；ATS 已 `NSAllowsArbitraryLoads: true`，
DJdd CDN 是 `http://bdcdn.djduoduo.com`，可直接播放/下载。

---

## DJ多多 API 协议（已实测）

```
基址  https://api.dianyinduoduo.com/v4/getlist.php
参数  ?act=<动作>&data=<base64(AES)>&extra=<base64(AES)>

分类  act=listtab   data={"PageNo":0,"type":"home"} → 首页 15 项
列表  act=<分类Act> data={"PageNo":p,"Id":分类Id}  → RetCode=200 Count=30
      最热/最新/无损专区 id=0 → 只传 act=hot/new/sq，不带 Id
音质  act=formats   data={"Id":歌曲Id,"Uid":Uid,"OpenId":OpenId,"Status":状态}
      ★ Uid=-1 即游客态 → RetCode=200 四档全返回（无需登录）
      响应 Item.Formats[]：Quality / Size / Bitrate / Path(加密，同媒体 key)
      档位 0 流畅 80k / 1 标准 128k / 2 高品 320k / 3 无损 1155k FLAC
下载  CDN/{Quality前缀}/{Id%1000补3位}/{Path解密文件名}
      前缀 0→dj  1→dj_nq  2→dj_hq  3→dj_sq
搜索  服务端 act=search 未开放 → 6 个分类首页聚合 + 本地过滤
封面  接口各模板实测 404 → 客户端按歌曲 Id 生成渐变封面 + 波形
歌词  act=lyric 为独立第五套密钥，未破解 → 不做歌词
```

AES：

```
AES-128-CBC + PKCS7
key = MD5("slf2yoDUOr3diocu")  iv = MD5("2mhamCk1helsrT")   (data/extra)
key = MD5("sdf2goDUOdjumogu")  iv = MD5("2ghlmCl1hblsqT")   (Path→文件名)
明文 NSJSONSerialization(prettyPrinted) 风格；base64 后 + / = 全部 %XX
★ 不缓存 Sign：列表接口带 Sign 会返回 403「请升级」
```

### 已知限制

- **搜索**：服务端 `act=search` 未开放，命中率受已加载分类限制，界面已标注「标题 / 上传者命中」。
- **封面**：接口封面模板全部 404，改用程序化渐变封面。
- **歌词**：不提供（独立密钥未破解）。
- **排行榜 / 云端歌单 / 歌手页 / 评论**：DJdd 无对应接口，已从界面移除。
- **收藏**：本地持久化（`beans.fav.djduoduo.v1`），无云端同步。
- **未真机验证**：Windows 环境无 Xcode / iOS 设备，仅做静态校验与 CI 编译；实机问题请附运行日志。