# 闪念 FlashMemo

一个卡片式速记 iOS App，交互参考「闪念笔记」与 flomo：快速记录、#标签 整理、每日回顾。

## 功能

- **快速记录**：右下角 ＋ 弹出输入框，支持文字、无序列表、最多 9 张图片
- **#标签**：输入 `#标签` 自动归类，支持多级标签 `#读书/小说`，输入 `#` 时自动联想已有标签
- **卡片时间线**：置顶、编辑、复制、分享、删除；长文自动折叠；点击卡片里的标签即可筛选
- **侧边栏**：笔记 / 标签 / 使用天数统计、最近 14 周记录热力图、标签树
- **全文搜索**
- **每日回顾**：「往年今日」+ 随机漫步，左右滑动翻阅
- **回收站**：可恢复，30 天后自动清除
- **导出 Markdown**
- 数据使用 SwiftData 仅保存在本机

## 技术栈

SwiftUI + SwiftData，iOS 17+，用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成工程。

## 获取 IPA

每次 push 都会由 GitHub Actions（`.github/workflows/build-ipa.yml`）在 macOS 上编译一个**未签名**的 `FlashMemo.ipa`：

- 仓库 **Releases → latest** 下载，或
- **Actions → Build IPA → 某次运行 → Artifacts → FlashMemo-ipa** 下载

未签名的 IPA 需要用 AltStore / SideStore / Sideloadly（用你的 Apple ID 重签）或 TrollStore 安装。

## 本地开发（macOS）

```bash
brew install xcodegen
xcodegen generate
open FlashMemo.xcodeproj
```

在 Xcode 的 Signing & Capabilities 里选择你的 Team，即可真机运行。
