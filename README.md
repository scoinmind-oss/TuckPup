<p align="center">
  <img src="Sources/TuckPup/Resources/BichonMenuIcon.png" width="112" alt="TuckPup Bichon mascot">
</p>

<h1 align="center">TuckPup</h1>

<p align="center">
  A lightweight, privacy-friendly menu bar organizer for macOS,<br>
  watched over by a tiny Bichon.
</p>

<p align="center">
  <a href="https://github.com/scoinmind-oss/TuckPup/releases/latest">Download</a>
  ·
  <a href="#中文">中文说明</a>
</p>

## English

TuckPup keeps a crowded macOS menu bar tidy. Choose which icons should stay
visible, tuck the rest away, and click the Bichon whenever you want to see them
again.

### Highlights

- Show or hide your chosen menu bar icons with one click.
- Keep important icons permanently visible.
- Put rarely used icons in an always-hidden section and open them in a compact,
  horizontally scrollable bar.
- Scroll up or down over the Bichon to show or hide normally hidden icons.
- Rehide icons automatically after a configurable delay.
- Launch automatically when you sign in to your Mac.
- Follow the macOS language automatically, or choose English, Simplified
  Chinese, or Japanese in Settings.
- Native AppKit app with no account, analytics, ads, or network access.
- Accessibility and Screen Recording are requested only when using the
  always-hidden icon bar.

### Requirements

- macOS 13 Ventura or later
- Apple Silicon Mac

### Install

1. Download the latest `TuckPup` ZIP from
   [GitHub Releases](https://github.com/scoinmind-oss/TuckPup/releases/latest).
2. Unzip it and move `TuckPup.app` to your Applications folder.
3. Open TuckPup.

TuckPup is locally signed but not yet notarized by Apple. If macOS blocks the
first launch, right-click `TuckPup.app` and choose **Open**. You can also allow
it from **System Settings → Privacy & Security → Open Anyway**.

### First-time setup

1. Launch TuckPup and choose **Start Setup**.
2. Hold `⌘` and drag the Bichon icon between the icons you want to hide and the
   icons you want to keep visible.
3. Still holding `⌘`, drag the temporary separator directly to the left of the
   Bichon.
4. Icons to the left of the separator will be tucked away. Icons to the right
   will remain visible.

### Controls

| Action | Result |
| --- | --- |
| Left-click the Bichon | Show or hide tucked icons |
| Right-click the Bichon | Open the TuckPup menu |
| `⌘` + drag | Reposition the Bichon or separator |

### Build from source

Install Xcode Command Line Tools, then run:

```sh
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

The app will be created at `dist/TuckPup.app`.

### Privacy

TuckPup does not connect to the internet, read your files, or collect analytics.
The optional always-hidden icon bar uses Accessibility to temporarily move and
click an original menu bar item, and Screen Recording to render its real icon.

### How it works

macOS does not provide a public API for hiding another app's menu bar item.
TuckPup uses an `NSStatusItem` separator as an anchor and changes its width to
move the icons on its left outside the visible menu bar area.

The core geometry technique was informed by the MIT-licensed
[Hidden Bar](https://github.com/dwarvesf/hidden) project. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for details.

---

## 中文

TuckPup 是一款由小比熊守着的原生 macOS 菜单栏收纳工具。你可以选择哪些图标
保持显示、哪些图标暂时收起，需要时点击小比熊即可重新展开。

### 主要功能

- 单击即可展开或收起选中的菜单栏图标。
- 重要图标可以始终保持显示。
- 不常用图标可以放入“永久隐藏”区，需要时在菜单栏下方的紧凑横向栏中打开。
- 在比熊头像上向上或向下滚动，可展开或收起普通隐藏图标。
- 支持按设定时间自动收起。
- 支持登录 Mac 时自动启动。
- 支持自动跟随 macOS 系统语言，也可在设置中手动选择 English、简体中文或
  日本語。
- 原生 AppKit 应用，无账户、无广告、无统计、无网络访问。
- 只有使用“永久隐藏”图标栏时才会请求辅助功能和屏幕录制权限。

### 系统要求

- macOS 13 Ventura 或更高版本
- Apple Silicon Mac

### 下载安装

1. 从 [GitHub Releases](https://github.com/scoinmind-oss/TuckPup/releases/latest)
   下载最新的 TuckPup 压缩包。
2. 解压后把 `TuckPup.app` 拖进“应用程序”文件夹。
3. 打开 TuckPup。

TuckPup 采用本地签名，尚未经过 Apple 公证。第一次启动若被系统拦截，请右键
点击 `TuckPup.app` 并选择“打开”，或前往“系统设置 → 隐私与安全性”选择
“仍要打开”。

### 首次设置

1. 启动 TuckPup，选择“开始设置”。
2. 按住 `⌘`，把比熊头像拖到隐藏区与常显区之间。
3. 继续按住 `⌘`，把临时出现的细分隔线紧贴在头像左侧。
4. 分隔线左侧的图标会被收纳，头像右侧的图标始终显示。

### 操作方式

| 操作 | 效果 |
| --- | --- |
| 左键点击比熊 | 展开或收起隐藏图标 |
| 右键点击比熊 | 打开 TuckPup 菜单 |
| 按住 `⌘` 拖动 | 调整比熊或分隔线的位置 |

### 从源码构建

安装 Xcode Command Line Tools 后运行：

```sh
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

构建结果位于 `dist/TuckPup.app`。

### 隐私

TuckPup 不联网、不读取用户文件、不收集数据。“永久隐藏”图标栏会使用辅助功能
权限临时移动并点击原生菜单栏图标，并使用屏幕录制权限显示图标的真实外观。

### 实现说明

macOS 没有公开 API 可以直接隐藏其他应用的菜单栏图标。TuckPup 使用一个
`NSStatusItem` 分隔锚点，通过改变它的宽度，把锚点左侧的图标移出可视区域。

核心几何思路参考了 MIT 许可的
[Hidden Bar](https://github.com/dwarvesf/hidden) 项目，详情见
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。
