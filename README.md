# TuckPup

一款由小比熊守着的原生 macOS 菜单栏收纳工具。

<img src="Sources/TuckPup/Resources/BichonMenuIcon.png" width="96" alt="TuckPup 比熊图标">

## 下载

从 GitHub Releases 下载 `TuckPup-0.1.0.zip`，解压后把 `TuckPup.app`
拖进“应用程序”文件夹。

当前版本支持 Apple Silicon Mac，需要 macOS 13 或更高版本。应用采用本地
临时签名，尚未经过 Apple 公证；第一次启动若被系统拦截，请右键点击应用并
选择“打开”，或前往“系统设置 → 隐私与安全性”选择“仍要打开”。

## 使用

1. 打开 `TuckPup.app`。
2. 第一次启动选择“开始设置”。
3. 按住 `⌘`，把比熊头像拖到隐藏区与常显区之间。
4. 继续按住 `⌘`，把临时出现的细分隔线紧贴在头像左侧。
5. 分隔线左侧的图标会被收纳，头像右侧图标始终显示。
6. 左键点击比熊头像展开或收起；右键打开菜单。

## 构建

需要 Xcode Command Line Tools 与 macOS 13 或更高版本。

```sh
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

构建结果位于 `dist/TuckPup.app`。

## 隐私

TuckPup 启用 App Sandbox，不联网、不读取用户文件、不收集数据，也不需要辅助
功能或屏幕录制权限。

## 实现说明

macOS 没有公开 API 可以直接隐藏其他应用的菜单栏图标。TuckPup 使用一个
`NSStatusItem` 分隔锚点，通过改变它的宽度，把锚点左侧的图标推出可视区域。

核心几何思路参考了 MIT 许可的 Hidden Bar 项目。详见
`THIRD_PARTY_NOTICES.md`。
