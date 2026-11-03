# 拾念 Shinian

一个卡片式速记 iOS App，交互参考 flomo 与闪念笔记：快速记录、#标签 整理、每日回顾。

## 功能

- **快速记录**：右下角 ＋ 弹出输入框，支持文字、无序列表、最多 9 张图片
- **#标签**：输入 `#标签` 自动归类，支持多级标签 `#读书/小说`，输入 `#` 时自动联想已有标签
- **卡片时间线**：置顶、编辑、复制、分享、删除；长文自动折叠；点击卡片里的标签即可筛选
- **侧边栏**：笔记 / 标签 / 使用天数统计、最近 14 周记录热力图、标签树
- **全文搜索**
- **每日回顾**：「往年今日」+ 随机漫步，左右滑动翻阅
- **回收站**：可恢复，30 天后自动清除
- **iCloud 同步**：SwiftData + CloudKit 私有数据库，笔记和图片在同一 Apple ID 的设备间自动同步（需付费开发者账号签名，见下文）
- **备份到 iCloud 云盘**：导出 / 恢复 JSON 备份（含图片），免费侧载也能用，恢复时自动去重
- **主题**：9 种主题色（薄荷绿、海盐蓝、靛青、薰衣草、樱花粉、珊瑚橙、琥珀黄、松针绿、石墨灰）+ 浅色 / 深色 / 跟随系统
- **导出 Markdown**

## 技术栈

SwiftUI + SwiftData，iOS 17+，用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成工程。

## 获取 IPA

每次 push 都会由 GitHub Actions（`.github/workflows/build-ipa.yml`）在 macOS 上编译一个**未签名**的 `Shinian.ipa`：

- 仓库 **Releases → latest** 下载，或
- **Actions → Build IPA → 某次运行 → Artifacts → Shinian-ipa** 下载

未签名的 IPA 需要用 AltStore / SideStore / Sideloadly（用你的 Apple ID 重签）或 TrollStore 安装。

## iCloud 同步怎么开启

CloudKit 同步需要 App 用**付费 Apple 开发者账号**（$99/年）签名，并带上 iCloud 权限。AltStore / SideStore 用免费 Apple ID 签名时**拿不到** iCloud 权限，这种情况下 App 会自动退回本机存储，请改用「设置 → 备份到 iCloud 云盘」。

### 方式一：Xcode 直接装到手机（最简单）

1. `xcodegen generate && open Shinian.xcodeproj`
2. Signing & Capabilities 选你的 Team；如果提示 Bundle ID 已被占用，改成你自己的（如 `com.yourname.shinian`），iCloud 容器同步改成 `iCloud.com.yourname.shinian`（在 `project.yml` 里改后重新生成）
3. 连上 iPhone 运行即可

### 方式二：GitHub Actions 自动出签名 IPA

1. 在 [Apple Developer](https://developer.apple.com/account/resources) 中：
   - Identifiers 新建 App ID `com.ganhoo.shinian`（或自定义），勾选 **iCloud（CloudKit）** 和 **Push Notifications**
   - 新建 iCloud Container `iCloud.<你的 Bundle ID>`，并在 App ID 的 iCloud 配置里关联它
   - Devices 中添加你的 iPhone UDID
   - 新建 **iOS App Development** 描述文件（包含上面的设备），下载 `.mobileprovision`
   - 导出你的开发证书为 `.p12`
2. 在仓库 Settings → Secrets and variables → Actions 中添加：

   | 类型 | 名称 | 值 |
   | --- | --- | --- |
   | Secret | `BUILD_CERTIFICATE_BASE64` | `base64 -i cert.p12` 的输出 |
   | Secret | `P12_PASSWORD` | p12 密码 |
   | Secret | `BUILD_PROVISION_PROFILE_BASE64` | `base64 -i profile.mobileprovision` 的输出 |
   | Secret | `TEAM_ID` | 10 位 Team ID |
   | Variable（可选） | `BUNDLE_ID` | 自定义 Bundle ID，默认 `com.ganhoo.shinian` |
   | Variable（可选） | `EXPORT_METHOD` | `development`（默认）/ `ad-hoc` / `app-store` |

3. 推送代码后，Releases → latest 会多出 `Shinian-iCloud.ipa`，用爱思助手 / Apple Configurator / Sideloadly 安装即可。

> 使用 `ad-hoc` 或 `app-store` 时连接的是 CloudKit **生产环境**，需要先在 [CloudKit Console](https://icloud.developer.apple.com) 把开发环境的 Schema 部署到生产环境（先用 development 版本运行一次生成 Schema）。

## 本地开发（macOS）

```bash
brew install xcodegen
xcodegen generate
open Shinian.xcodeproj
```

在 Xcode 的 Signing & Capabilities 里选择你的 Team，即可真机运行。

## 发版约定

每次更新：
1. `project.yml` 中提升 `MARKETING_VERSION` / `CFBundleShortVersionString` 和 `CURRENT_PROJECT_VERSION` / `CFBundleVersion`
2. 在 `Sources/Utils/Changelog.swift` 最前面加一条更新内容（App 内 设置 → 关于 → 版本 可查看）
