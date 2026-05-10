# MacModeMenu

MacModeMenu 是一个原生 macOS 菜单栏工具，用来快速切换“笔记本模式”和“4K 显示器模式”，同时管理一组常用 App 的退出、恢复和桌面收起操作。

这个项目主要面向这样的场景：MacBook 连接 4K 显示器，但显示器也会切到 PC 输入源。此时 macOS 仍然认为外接屏在线，桌面排列、分辨率和窗口位置容易变得别扭。MacModeMenu 提供一组菜单栏按钮，把这些日常操作合成更顺手的一键模式。

## 功能

- 菜单栏快速切换笔记本模式、4K 显示器模式、镜像模式和扩展模式
- 保存当前显示器配置，并尝试恢复合适的 HiDPI 分辨率和刷新率
- 记录当前运行的普通 App，之后一键退出或重新打开
- 为每个已记录 App 单独设置是否参与“重新打开”
- 一键收起当前所有普通 App 窗口，不关闭进程
- 打开配置文件夹，便于备份或手动清理配置

## 系统要求

- macOS 14 或更新版本
- Swift 6.0 或更新版本

## 运行

```bash
swift run
```

运行后会打开 `Mac模式` 主窗口，同时菜单栏会出现 `Mac模式` 快捷菜单。

## 打包成 App

```bash
chmod +x scripts/package_app.sh
scripts/package_app.sh
open "build/Mac模式.app"
```

脚本会执行 release 构建，并生成：

```text
build/Mac模式.app
```

## 使用方式

### 屏幕设置

1. 打开主窗口左侧的 `屏幕设置`。
2. 连接 4K 显示器，把 macOS 显示设置调成外接屏工作时常用的状态。
3. 点击 `保存当前为4K显示器模式`。
4. 把桌面调成只用 MacBook 时舒服的状态。
5. 点击 `保存当前为笔记本模式`。
6. 之后需要切到 PC 输入源时，点击 `笔记本模式`。
7. 回到外接屏工作时，点击 `4K显示器模式`。

也可以单独使用 `镜像模式`、`扩展模式`，或在 `帧率改变` 里选择当前显示器支持的刷新率。

### 一键退出 App

1. 在平时工作环境下点击 `记录当前运行的App`。
2. 主窗口会显示已记录 App 的图标、名称、恢复开关和运行状态。
3. 可以多选后批量 `退出选中`、`重新打开选中` 或 `从记录移除`。
4. 取消某个 App 的 `重新打开` 勾选后，它会保留在记录里，但不会参与一键恢复。
5. 在列表行上横向滑动，可以快速打开、退出、设置不恢复或取消记录。

### 清空桌面

点击 `收起所有窗口` 后，MacModeMenu 会隐藏当前普通 App 的窗口，但不会关闭对应进程。

## 配置文件

配置文件保存在：

```text
~/Library/Application Support/MacModeMenu/
```

常见文件包括：

```text
apps.json
laptop-display.json
monitor-display.json
preferred-display.json
```

## 技术说明

MacModeMenu 使用 Swift Package Manager 构建，界面基于 AppKit，显示器控制基于 CoreGraphics，通知基于 UserNotifications。

由于 macOS 对“完全忽略仍然连接着的外接显示器”限制较多，项目采用公开 API 能稳定做到的方式：镜像到内置屏、切回扩展模式、尝试应用系统可用的 HiDPI 显示模式，以及安全退出普通 App。

## 项目结构

```text
.
├── Bundle/Info.plist
├── Package.swift
├── Sources/MacModeMenu/main.swift
└── scripts/package_app.sh
```

## 注意事项

- 首次运行时，macOS 可能会询问通知权限。
- 显示器模式是否能完全切换成功，取决于当前硬件、线材、显示器输入源和 macOS 暴露的显示模式。
- App 退出逻辑会尽量使用正常退出方式，避免强杀系统组件、输入法、同步服务或当前菜单栏程序。
