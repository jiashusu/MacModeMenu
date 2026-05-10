import AppKit
import CoreGraphics
import Foundation
import UserNotifications

@main
@MainActor
final class MacModeMenuApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let store = ProfileStore()
    private lazy var displayManager = DisplayManager(store: store)
    private lazy var processManager = ProcessManager(store: store)
    private lazy var windowController = AppWindowController(
        displayManager: displayManager,
        processManager: processManager,
        store: store
    )

    static func main() {
        let app = NSApplication.shared
        let delegate = MacModeMenuApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Mac模式"
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        rebuildMenu()
        showMainWindow()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        menu.addItem(disabled("显示器"))
        menu.addItem(action("切到笔记本模式", #selector(switchToLaptopMode)))
        menu.addItem(action("切到4K显示器模式", #selector(switchToMonitorMode)))
        menu.addItem(action("镜像模式", #selector(switchToMirrorMode)))
        menu.addItem(action("扩展模式", #selector(switchToExtendedMode)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(action("保存当前为笔记本模式", #selector(saveLaptopProfile)))
        menu.addItem(action("保存当前为4K显示器模式", #selector(saveMonitorProfile)))

        menu.addItem(NSMenuItem.separator())
        menu.addItem(disabled("进程"))
        menu.addItem(action("打开管理窗口", #selector(showMainWindow)))
        menu.addItem(action("一键收起所有窗口", #selector(hideCurrentVisibleApps)))
        menu.addItem(action("记录当前运行的App", #selector(saveAppProfile)))
        menu.addItem(action("退出已记录的App", #selector(quitSavedApps)))
        menu.addItem(action("重新打开已记录的App", #selector(reopenSavedApps)))
        menu.addItem(action("退出当前普通App", #selector(quitCurrentVisibleApps)))

        menu.addItem(NSMenuItem.separator())
        menu.addItem(action("打开配置文件夹", #selector(openConfigFolder)))
        menu.addItem(action("刷新菜单", #selector(refreshMenu)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(action("退出 Mac模式", #selector(quit)))

        statusItem.menu = menu
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func saveLaptopProfile() {
        run("已保存笔记本模式") { try displayManager.saveProfile(named: .laptop) }
    }

    @objc private func saveMonitorProfile() {
        run("已保存4K显示器模式") { try displayManager.saveProfile(named: .monitor) }
    }

    @objc private func switchToLaptopMode() {
        run("已切到笔记本模式") { try displayManager.switchToLaptopMode() }
    }

    @objc private func switchToMonitorMode() {
        run("已切到4K显示器模式") { try displayManager.switchToMonitorMode() }
    }

    @objc private func switchToMirrorMode() {
        run("已切到镜像模式") { try displayManager.switchToMirrorMode() }
    }

    @objc private func switchToExtendedMode() {
        run("已切到扩展模式") { try displayManager.switchToExtendedMode() }
    }

    @objc private func saveAppProfile() {
        run("已记录当前运行的App") { try processManager.saveCurrentApps() }
        windowController.reload()
    }

    @objc private func quitSavedApps() {
        run("已请求退出记录的App") { try processManager.quitSavedApps() }
    }

    @objc private func reopenSavedApps() {
        run("已重新打开记录的App") { try processManager.reopenSavedApps() }
    }

    @objc private func quitCurrentVisibleApps() {
        run("已请求退出当前普通App") { try processManager.quitCurrentVisibleApps() }
    }

    @objc private func hideCurrentVisibleApps() {
        run("已收起当前所有窗口，进程仍在运行") { try processManager.hideCurrentVisibleApps() }
    }

    @objc private func openConfigFolder() {
        NSWorkspace.shared.open(store.directory)
    }

    @objc private func showMainWindow() {
        windowController.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func refreshMenu() {
        rebuildMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func run(_ success: String, _ work: () throws -> Void) {
        do {
            try work()
            notify(title: "Mac模式", message: success)
        } catch {
            notify(title: "Mac模式出错", message: error.localizedDescription)
        }
    }

    private func notify(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

enum ProfileName: String, Codable {
    case laptop
    case monitor
}

struct DisplayProfile: Codable {
    var displays: [SavedDisplay]
}

struct SavedDisplay: Codable {
    var id: UInt32
    var vendor: UInt32
    var model: UInt32
    var serial: UInt32
    var width: Int
    var height: Int
    var pixelWidth: Int?
    var pixelHeight: Int?
    var refreshRate: Double
    var isBuiltin: Bool
    var ioFlags: UInt32?
    var localizedName: String?
}

enum PreferredDisplayTarget: String, Codable {
    case builtin
    case external
}

struct PreferredDisplayState: Codable {
    var target: PreferredDisplayTarget
}

struct DisplayStatus {
    var mainDisplayName: String
    var displayModeName: String
}

struct AppProfile: Codable {
    var apps: [SavedApp]
}

struct DesktopWindow: Hashable {
    var id: UInt32
    var ownerPID: pid_t
    var ownerName: String
    var title: String
    var bounds: CGRect
    var bundleIdentifier: String?
    var bundlePath: String?

    var displayTitle: String {
        title.isEmpty ? ownerName : title
    }
}

struct SavedApp: Codable, Hashable {
    var bundleIdentifier: String?
    var bundlePath: String?
    var localizedName: String?
    var shouldReopen: Bool

    init(
        bundleIdentifier: String?,
        bundlePath: String?,
        localizedName: String?,
        shouldReopen: Bool = true
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.bundlePath = bundlePath
        self.localizedName = localizedName
        self.shouldReopen = shouldReopen
    }

    enum CodingKeys: String, CodingKey {
        case bundleIdentifier
        case bundlePath
        case localizedName
        case shouldReopen
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        bundlePath = try container.decodeIfPresent(String.self, forKey: .bundlePath)
        localizedName = try container.decodeIfPresent(String.self, forKey: .localizedName)
        shouldReopen = try container.decodeIfPresent(Bool.self, forKey: .shouldReopen) ?? true
    }
}

final class ProfileStore {
    let directory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("MacModeMenu", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save<T: Encodable>(_ value: T, as filename: String) throws {
        let data = try JSONEncoder.pretty.encode(value)
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        let url = directory.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

final class DisplayManager {
    private let store: ProfileStore
    private let displayModeOptions = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary

    init(store: ProfileStore) {
        self.store = store
    }

    func saveProfile(named name: ProfileName) throws {
        let profile = DisplayProfile(displays: activeDisplays().compactMap { displayID in
            guard let mode = CGDisplayCopyDisplayMode(displayID) else { return nil }
            return SavedDisplay(
                id: displayID,
                vendor: CGDisplayVendorNumber(displayID),
                model: CGDisplayModelNumber(displayID),
                serial: CGDisplaySerialNumber(displayID),
                width: mode.width,
                height: mode.height,
                pixelWidth: mode.pixelWidth,
                pixelHeight: mode.pixelHeight,
                refreshRate: mode.refreshRate,
                isBuiltin: CGDisplayIsBuiltin(displayID) != 0,
                ioFlags: mode.ioFlags,
                localizedName: displayName(for: displayID)
            )
        })
        try store.save(profile, as: "\(name.rawValue)-display.json")
    }

    func switchToLaptopMode() throws {
        guard let builtin = activeDisplays().first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
            throw AppError("没有找到内置显示屏。")
        }
        try savePreferredDisplayTarget(.builtin)
        try unmirrorAllDisplays()
        try applyDefaultModeIfAvailable(for: builtin)
        try makeMainDisplayIfPossible(builtin)
        try mirrorAllDisplays(to: builtin)
    }

    func switchToMonitorMode() throws {
        try savePreferredDisplayTarget(.external)
        try unmirrorAllDisplays()
        for display in activeDisplays() where CGDisplayIsBuiltin(display) == 0 {
            try applyDefaultModeIfAvailable(for: display)
        }
        if let external = preferredExternalDisplay() {
            try makeMainDisplayIfPossible(external)
        }
    }

    func switchToMirrorMode() throws {
        guard let master = preferredMirrorMasterDisplay() else {
            throw AppError("没有找到可用于镜像的显示器。")
        }
        try unmirrorAllDisplays()
        try makeMainDisplayIfPossible(master)
        try mirrorAllDisplays(to: master)
    }

    func switchToExtendedMode() throws {
        try unmirrorAllDisplays()
        if let main = preferredMainDisplay() {
            try makeMainDisplayIfPossible(main)
        }
    }

    func status() -> DisplayStatus {
        let main = CGMainDisplayID()
        return DisplayStatus(
            mainDisplayName: displayName(for: main),
            displayModeName: isMirroring() ? "镜像" : "扩展"
        )
    }

    func availableRefreshRates() -> [Double] {
        guard let displayID = preferredAdjustableDisplay(),
              let currentMode = CGDisplayCopyDisplayMode(displayID),
              let modes = CGDisplayCopyAllDisplayModes(displayID, displayModeOptions) as? [CGDisplayMode] else {
            return []
        }

        let rates = modes
            .filter {
                $0.width == currentMode.width &&
                $0.height == currentMode.height &&
                $0.pixelWidth == currentMode.pixelWidth &&
                $0.pixelHeight == currentMode.pixelHeight
            }
            .map(\.refreshRate)
            .filter { $0 > 0 }
        return Array(Set(rates)).sorted()
    }

    func currentRefreshRate() -> Double? {
        guard let displayID = preferredAdjustableDisplay(),
              let mode = CGDisplayCopyDisplayMode(displayID),
              mode.refreshRate > 0 else {
            return nil
        }
        return mode.refreshRate
    }

    func setRefreshRate(_ refreshRate: Double) throws {
        guard let displayID = preferredAdjustableDisplay(),
              let currentMode = CGDisplayCopyDisplayMode(displayID),
              let modes = CGDisplayCopyAllDisplayModes(displayID, displayModeOptions) as? [CGDisplayMode] else {
            throw AppError("没有找到可调帧率的显示器。")
        }

        guard let mode = modes.min(by: { left, right in
            let leftScore = abs(left.refreshRate - refreshRate)
                + Double(abs(left.width - currentMode.width) + abs(left.height - currentMode.height))
                + Double(abs(left.pixelWidth - currentMode.pixelWidth) + abs(left.pixelHeight - currentMode.pixelHeight)) * 4
                + (isHiDPI(currentMode) && !isHiDPI(left) ? 10_000 : 0)
            let rightScore = abs(right.refreshRate - refreshRate)
                + Double(abs(right.width - currentMode.width) + abs(right.height - currentMode.height))
                + Double(abs(right.pixelWidth - currentMode.pixelWidth) + abs(right.pixelHeight - currentMode.pixelHeight)) * 4
                + (isHiDPI(currentMode) && !isHiDPI(right) ? 10_000 : 0)
            return leftScore < rightScore
        }) else {
            throw AppError("没有找到 \(Int(refreshRate))Hz 对应的显示模式。")
        }

        let error = CGDisplaySetDisplayMode(displayID, mode, nil)
        if error != .success {
            throw AppError("设置帧率失败：\(error.rawValue)")
        }
    }

    private func applyProfileIfAvailable(_ name: ProfileName, only filter: ((SavedDisplay) -> Bool)?) throws {
        guard let profile = try? store.load(DisplayProfile.self, from: "\(name.rawValue)-display.json") else {
            return
        }
        for saved in profile.displays where filter?(saved) ?? true {
            guard let displayID = matchingDisplay(for: saved),
                  let mode = bestMode(for: displayID, saved: saved) else { continue }
            let error = CGDisplaySetDisplayMode(displayID, mode, nil)
            if error != .success {
                throw AppError("设置显示器 \(saved.width)x\(saved.height) 失败：\(error.rawValue)")
            }
        }
    }

    private func applyDefaultModeIfAvailable(for displayID: CGDirectDisplayID) throws {
        guard let mode = defaultMode(for: displayID) else { return }
        let error = CGDisplaySetDisplayMode(displayID, mode, nil)
        if error != .success {
            throw AppError("设置默认分辨率失败：\(error.rawValue)")
        }
    }

    private func savePreferredDisplayTarget(_ target: PreferredDisplayTarget) throws {
        try store.save(PreferredDisplayState(target: target), as: "preferred-display.json")
    }

    private func preferredDisplayTarget() -> PreferredDisplayTarget {
        (try? store.load(PreferredDisplayState.self, from: "preferred-display.json").target) ?? .builtin
    }

    private func mirrorAllDisplays(to master: CGDirectDisplayID) throws {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else {
            throw AppError("无法开始显示器配置。")
        }

        for display in activeDisplays() where display != master {
            CGConfigureDisplayMirrorOfDisplay(config, display, master)
        }

        let error = CGCompleteDisplayConfiguration(config, .permanently)
        if error != .success {
            throw AppError("切换镜像显示失败：\(error.rawValue)")
        }
    }

    private func unmirrorAllDisplays() throws {
        let mirroredDisplays = onlineDisplays().filter {
            CGDisplayMirrorsDisplay($0) != kCGNullDirectDisplay
        }
        guard !mirroredDisplays.isEmpty else { return }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else {
            throw AppError("无法开始显示器配置。")
        }

        for display in mirroredDisplays {
            let error = CGConfigureDisplayMirrorOfDisplay(config, display, kCGNullDirectDisplay)
            if error != .success {
                CGCancelDisplayConfiguration(config)
                throw AppError("取消镜像显示失败：\(error.rawValue)")
            }
        }

        let error = CGCompleteDisplayConfiguration(config, .permanently)
        if error != .success {
            throw AppError("取消镜像显示失败：\(error.rawValue)")
        }
    }

    private func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        return displays
    }

    private func onlineDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &displays, &count)
        return displays
    }

    private func preferredAdjustableDisplay() -> CGDirectDisplayID? {
        let displays = activeDisplays()
        return displays.first(where: { CGDisplayIsBuiltin($0) == 0 }) ?? displays.first
    }

    private func preferredMainDisplay() -> CGDirectDisplayID? {
        switch preferredDisplayTarget() {
        case .builtin:
            return activeDisplays().first(where: { CGDisplayIsBuiltin($0) != 0 }) ?? activeDisplays().first
        case .external:
            return preferredExternalDisplay() ?? activeDisplays().first
        }
    }

    private func preferredMirrorMasterDisplay() -> CGDirectDisplayID? {
        preferredMainDisplay()
    }

    private func preferredExternalDisplay() -> CGDirectDisplayID? {
        activeDisplays().first(where: { CGDisplayIsBuiltin($0) == 0 })
    }

    private func makeMainDisplay(_ main: CGDirectDisplayID) throws {
        let displays = activeDisplays()
        guard displays.count > 1 else { return }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else {
            throw AppError("无法开始显示器排列配置。")
        }

        CGConfigureDisplayOrigin(config, main, 0, 0)
        var nextX: Int32 = Int32(CGDisplayPixelsWide(main))
        for display in displays where display != main {
            CGConfigureDisplayOrigin(config, display, nextX, 0)
            nextX += Int32(CGDisplayPixelsWide(display))
        }

        let error = CGCompleteDisplayConfiguration(config, .permanently)
        if error != .success {
            throw AppError("设置主显示器失败：\(error.rawValue)")
        }
    }

    private func makeMainDisplayIfPossible(_ main: CGDirectDisplayID) throws {
        do {
            try makeMainDisplay(main)
        } catch {
            // Some display states reject origin changes while still allowing mode/mirror changes.
            // Do not block the user's requested mode switch for this softer preference.
        }
    }

    private func isMirroring() -> Bool {
        activeDisplays().contains { displayID in
            CGDisplayMirrorsDisplay(displayID) != kCGNullDirectDisplay
                || CGDisplayIsInMirrorSet(displayID) != 0
        }
    }

    private func displayName(for displayID: CGDirectDisplayID) -> String {
        if let screen = NSScreen.screens.first(where: { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        }) {
            return screen.localizedName
        }

        if CGDisplayIsBuiltin(displayID) != 0 {
            return "内建显示器"
        }
        return "显示器 \(displayID)"
    }

    private func matchingDisplay(for saved: SavedDisplay) -> CGDirectDisplayID? {
        activeDisplays().first { displayID in
            CGDisplayVendorNumber(displayID) == saved.vendor &&
            CGDisplayModelNumber(displayID) == saved.model &&
            CGDisplaySerialNumber(displayID) == saved.serial
        } ?? activeDisplays().first { displayID in
            CGDisplayIsBuiltin(displayID) != 0 && saved.isBuiltin
        }
    }

    private func bestMode(for displayID: CGDirectDisplayID, saved: SavedDisplay) -> CGDisplayMode? {
        guard let modes = CGDisplayCopyAllDisplayModes(displayID, displayModeOptions) as? [CGDisplayMode] else {
            return nil
        }
        return modes.min { left, right in
            score(left, saved: saved) < score(right, saved: saved)
        }
    }

    private func defaultMode(for displayID: CGDirectDisplayID) -> CGDisplayMode? {
        guard let modes = CGDisplayCopyAllDisplayModes(displayID, displayModeOptions) as? [CGDisplayMode] else {
            return nil
        }
        let nativeMode = modes
            .filter { !isHiDPI($0) }
            .max { left, right in
                (left.width * left.height) < (right.width * right.height)
            }
        let nativeWidth = nativeMode?.width ?? modes.map(\.pixelWidth).max() ?? 0
        let nativeHeight = nativeMode?.height ?? modes.map(\.pixelHeight).max() ?? 0
        let currentRefresh = CGDisplayCopyDisplayMode(displayID)?.refreshRate ?? 0

        let candidates = modes.filter {
            isHiDPI($0) &&
            $0.width * 2 == nativeWidth &&
            $0.height * 2 == nativeHeight &&
            $0.pixelWidth == nativeWidth &&
            $0.pixelHeight == nativeHeight
        }
        let pool = candidates.isEmpty ? modes.filter { isHiDPI($0) } : candidates
        return pool.min { left, right in
            defaultScore(left, currentRefresh: currentRefresh, nativeWidth: nativeWidth, nativeHeight: nativeHeight)
                < defaultScore(right, currentRefresh: currentRefresh, nativeWidth: nativeWidth, nativeHeight: nativeHeight)
        }
    }

    private func defaultScore(
        _ mode: CGDisplayMode,
        currentRefresh: Double,
        nativeWidth: Int,
        nativeHeight: Int
    ) -> Double {
        let defaultFlagPenalty = (mode.ioFlags & 4) != 0 ? 0 : 5_000
        let pixelPenalty = abs(mode.pixelWidth - nativeWidth) + abs(mode.pixelHeight - nativeHeight)
        let logicalPenalty = abs(mode.width * 2 - nativeWidth) + abs(mode.height * 2 - nativeHeight)
        let refreshPenalty = currentRefresh > 0 ? abs(mode.refreshRate - currentRefresh) : -mode.refreshRate
        return Double(defaultFlagPenalty + pixelPenalty * 4 + logicalPenalty) + refreshPenalty
    }

    private func score(_ mode: CGDisplayMode, saved: SavedDisplay) -> Double {
        let savedPixelWidth = saved.pixelWidth ?? saved.width
        let savedPixelHeight = saved.pixelHeight ?? saved.height
        let pointSize = abs(mode.width - saved.width) + abs(mode.height - saved.height)
        let pixelSize = abs(mode.pixelWidth - savedPixelWidth) + abs(mode.pixelHeight - savedPixelHeight)
        let refresh = mode.refreshRate > 0 && saved.refreshRate > 0 ? abs(mode.refreshRate - saved.refreshRate) : 0
        let hidpiPenalty = prefersHiDPI(saved) && !isHiDPI(mode) ? 10_000 : 0
        let flagPenalty = saved.ioFlags == mode.ioFlags ? 0 : 50
        return Double(pixelSize * 4 + pointSize + hidpiPenalty + flagPenalty) + refresh
    }

    private func prefersHiDPI(_ saved: SavedDisplay) -> Bool {
        guard let pixelWidth = saved.pixelWidth, let pixelHeight = saved.pixelHeight else {
            return true
        }
        return pixelWidth > saved.width || pixelHeight > saved.height
    }

    private func isHiDPI(_ mode: CGDisplayMode) -> Bool {
        mode.pixelWidth > mode.width || mode.pixelHeight > mode.height
    }
}

@MainActor
final class ProcessManager {
    private let store: ProfileStore
    private let ownBundleIdentifier = Bundle.main.bundleIdentifier

    init(store: ProfileStore) {
        self.store = store
    }

    func saveCurrentApps() throws {
        let existing = (try? loadProfile().apps) ?? []
        let reopenByKey = Dictionary(uniqueKeysWithValues: existing.map { ($0.identityKey, $0.shouldReopen) })
        let apps = NSWorkspace.shared.runningApplications
            .filter(isUserQuitCandidate)
            .map {
                let app = SavedApp(
                    bundleIdentifier: $0.bundleIdentifier,
                    bundlePath: $0.bundleURL?.path,
                    localizedName: $0.localizedName,
                    shouldReopen: true
                )
                var merged = app
                merged.shouldReopen = reopenByKey[app.identityKey] ?? true
                return merged
            }
            .uniqued()
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        try store.save(AppProfile(apps: apps), as: "apps.json")
    }

    func loadProfile() throws -> AppProfile {
        try store.load(AppProfile.self, from: "apps.json")
    }

    func saveProfile(_ profile: AppProfile) throws {
        try store.save(profile, as: "apps.json")
    }

    func quitSavedApps() throws {
        try quit(apps: loadProfile().apps)
    }

    func quit(apps savedApps: [SavedApp]) throws {
        let savedIDs = Set(savedApps.compactMap(\.bundleIdentifier))
        let savedPaths = Set(savedApps.compactMap(\.bundlePath))

        for app in NSWorkspace.shared.runningApplications where isUserQuitCandidate(app) {
            if let id = app.bundleIdentifier, savedIDs.contains(id) {
                app.terminate()
            } else if let path = app.bundleURL?.path, savedPaths.contains(path) {
                app.terminate()
            }
        }
    }

    func reopenSavedApps() throws {
        try reopen(apps: loadProfile().apps.filter(\.shouldReopen))
    }

    func reopen(apps: [SavedApp]) throws {
        for app in apps {
            if let bundleIdentifier = app.bundleIdentifier,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            } else if let path = app.bundlePath {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            }
        }
    }

    func quitCurrentVisibleApps() throws {
        for app in NSWorkspace.shared.runningApplications where isUserQuitCandidate(app) {
            app.terminate()
        }
    }

    func hideCurrentVisibleApps() throws {
        NSApplication.shared.hideOtherApplications(nil)

        for app in NSWorkspace.shared.runningApplications where isUserHideCandidate(app) {
            app.hide()
        }

        NSApplication.shared.hide(nil)
    }

    func visibleDesktopWindows() -> [DesktopWindow] {
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else {
            return []
        }

        let appsByPID = Dictionary(uniqueKeysWithValues: NSWorkspace.shared.runningApplications.map {
            ($0.processIdentifier, $0)
        })

        return infoList.compactMap { info in
            guard let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  layer == 0,
                  let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue,
                  alpha > 0,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo) else {
                return nil
            }

            guard bounds.width >= 90, bounds.height >= 70 else { return nil }
            guard let app = appsByPID[pid], isUserWindowCandidate(app) else { return nil }
            guard app.bundleIdentifier != ownBundleIdentifier else { return nil }

            return DesktopWindow(
                id: id,
                ownerPID: pid,
                ownerName: app.localizedName ?? ownerName,
                title: info[kCGWindowName as String] as? String ?? "",
                bounds: bounds,
                bundleIdentifier: app.bundleIdentifier,
                bundlePath: app.bundleURL?.path
            )
        }
    }

    func hide(windows: [DesktopWindow]) throws {
        let pids = Set(windows.map(\.ownerPID))
        for app in NSWorkspace.shared.runningApplications
            where pids.contains(app.processIdentifier) && isUserHideCandidate(app) {
            app.hide()
        }
    }

    func activate(window: DesktopWindow) {
        NSWorkspace.shared.runningApplications
            .first { $0.processIdentifier == window.ownerPID }?
            .activate(options: [.activateAllWindows])
    }

    private func isUserQuitCandidate(_ app: NSRunningApplication) -> Bool {
        guard app.activationPolicy == .regular else { return false }
        guard app.bundleIdentifier != ownBundleIdentifier else { return false }
        guard app.bundleIdentifier != "com.apple.finder" else { return false }
        return true
    }

    private func isUserHideCandidate(_ app: NSRunningApplication) -> Bool {
        guard isUserWindowCandidate(app) else { return false }
        guard app.bundleIdentifier != ownBundleIdentifier else { return false }
        return true
    }

    private func isUserWindowCandidate(_ app: NSRunningApplication) -> Bool {
        app.activationPolicy == .regular || app.activationPolicy == .accessory
    }
}

private extension SavedApp {
    var identityKey: String {
        bundleIdentifier ?? bundlePath ?? localizedName ?? UUID().uuidString
    }
}

@MainActor
final class AppWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegate {
    private enum Mode: CaseIterable {
        case display
        case appExit
        case desktop

        var title: String {
            switch self {
            case .display: "屏幕设置"
            case .appExit: "一键退出App模式"
            case .desktop: "清空桌面模式"
            }
        }

        var symbol: String {
            switch self {
            case .display: "display"
            case .appExit: "power"
            case .desktop: "rectangle.dashed"
            }
        }
    }

    private let displayManager: DisplayManager
    private let processManager: ProcessManager
    private let store: ProfileStore
    private var apps: [SavedApp] = []
    private let tableView = ContextSelectingTableView()
    private let countLabel = NSTextField(labelWithString: "")
    private let contentStack = FlippedStackView()
    private var runningAppKeys = Set<String>()
    private var quittingAppKeys = Set<String>()
    private var quitRefreshTimer: Timer?
    private var quitRefreshDeadline: Date?
    private var desktopWindows: [DesktopWindow] = []
    private let windowCollectionView = ContextSelectingCollectionView()
    private let windowCountLabel = NSTextField(labelWithString: "")
    private var sidebarButtons: [Mode: NSButton] = [:]
    private var selectedMode: Mode = .display
    private let contentWidth: CGFloat = 820
    private let sidebarWidth: CGFloat = 220
    private let windowBackground = NSColor(red: 0.120, green: 0.120, blue: 0.125, alpha: 1)
    private let sidebarBackground = NSColor(red: 0.265, green: 0.265, blue: 0.265, alpha: 1)
    private let cardBackground = NSColor(red: 0.170, green: 0.170, blue: 0.175, alpha: 1)
    private let dividerColor = NSColor.white.withAlphaComponent(0.055)

    init(displayManager: DisplayManager, processManager: ProcessManager, store: ProfileStore) {
        self.displayManager = displayManager
        self.processManager = processManager
        self.store = store

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Mac模式"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = windowBackground
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 1040, height: 680)
        super.init(window: window)
        window.center()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(runningApplicationTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        buildInterface()
        reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reload() {
        apps = (try? processManager.loadProfile().apps) ?? []
        refreshRunningAppKeys()
        tableView.reloadData()
        updateCount()
    }

    private func buildInterface() {
        guard let contentView = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .horizontal
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let sidebar = makeSidebar()
        sidebar.widthAnchor.constraint(equalToConstant: sidebarWidth).isActive = true
        root.addArrangedSubview(sidebar)

        configureTable()
        configureWindowCollection()

        let scrollView = NSScrollView()
        scrollView.contentView = FlippedClipView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 18
        contentStack.edgeInsets = NSEdgeInsets(top: 30, left: 36, bottom: 30, right: 36)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentStack
        root.addArrangedSubview(scrollView)

        NSLayoutConstraint.activate([
            contentStack.widthAnchor.constraint(equalToConstant: contentWidth + 72)
        ])

        renderSelectedMode()
    }

    private func makeSidebar() -> NSView {
        let sidebar = NSView()
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = sidebarBackground.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 72, left: 18, bottom: 22, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            stack.topAnchor.constraint(equalTo: sidebar.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: sidebar.bottomAnchor)
        ])

        let modeLabel = sidebarSectionLabel("模式")
        stack.addArrangedSubview(modeLabel)
        stack.addArrangedSubview(spacer(height: 4))

        for mode in Mode.allCases {
            let button = sidebarButton(for: mode)
            sidebarButtons[mode] = button
            stack.addArrangedSubview(button)
        }

        stack.addArrangedSubview(NSView())
        updateSidebarSelection()
        return sidebar
    }

    private func sidebarButton(for mode: Mode) -> NSButton {
        let button = NSButton(title: "  \(mode.title)", target: self, action: #selector(selectMode(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(mode.title)
        button.image = NSImage(systemSymbolName: mode.symbol, accessibilityDescription: mode.title)
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.controlSize = .large
        button.font = .systemFont(ofSize: 16, weight: .semibold)
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.widthAnchor.constraint(equalToConstant: sidebarWidth - 36).isActive = true
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return button
    }

    private func sidebarSectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = NSColor.white.withAlphaComponent(0.38)
        label.alignment = .left
        return label
    }

    @objc private func selectMode(_ sender: NSButton) {
        guard let title = sender.identifier?.rawValue,
              let mode = Mode.allCases.first(where: { $0.title == title }) else { return }
        selectedMode = mode
        updateSidebarSelection()
        renderSelectedMode()
    }

    private func updateSidebarSelection() {
        for (mode, button) in sidebarButtons {
            let isSelected = mode == selectedMode
            button.contentTintColor = isSelected ? .white : NSColor.white.withAlphaComponent(0.72)
            button.layer?.backgroundColor = isSelected ? NSColor.controlAccentColor.cgColor : NSColor.clear.cgColor
            button.state = mode == selectedMode ? .on : .off
        }
    }

    private func renderSelectedMode() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        switch selectedMode {
        case .display:
            buildDisplayPage()
        case .appExit:
            buildAppExitPage()
        case .desktop:
            buildDesktopPage()
        }
    }

    private func buildDisplayPage() {
        contentStack.addArrangedSubview(pageTitle("屏幕设置", subtitle: "管理外接 4K 显示器、笔记本屏幕、镜像/扩展和帧率。"))
        contentStack.addArrangedSubview(displayStatusView())

        contentStack.addArrangedSubview(section("常用模式", rows: [
            serviceRow(
                title: "笔记本模式",
                detail: "显示器输入切到 PC 时使用：镜像到内置屏，并恢复你保存的笔记本显示配置。",
                controls: [
                    button("启用", action: #selector(switchToLaptopMode))
                ]
            ),
            serviceRow(
                title: "4K 显示器模式",
                detail: "回到 Mac 外接屏时使用：切回扩展桌面，并恢复你保存的 4K 显示配置。",
                controls: [
                    button("启用", action: #selector(switchToMonitorMode))
                ]
            )
        ]))

        contentStack.addArrangedSubview(section("显示方式", rows: [
            serviceRow(
                title: "镜像模式",
                detail: "所有外接屏镜像到内置屏。适合外接显示器还连着 Mac，但你实际在旁边只看笔记本屏幕。",
                controls: [
                    button("切到镜像", action: #selector(switchToMirrorMode))
                ]
            ),
            serviceRow(
                title: "扩展模式",
                detail: "取消镜像，恢复多屏扩展桌面。适合重新使用 4K 显示器。",
                controls: [
                    button("切到扩展", action: #selector(switchToExtendedMode))
                ]
            )
        ]))

        let refreshPopup = NSPopUpButton()
        refreshPopup.target = self
        refreshPopup.action = #selector(changeRefreshRate(_:))
        let rates = displayManager.availableRefreshRates()
        if rates.isEmpty {
            refreshPopup.addItem(withTitle: "当前显示器不支持切换")
            refreshPopup.isEnabled = false
        } else {
            for rate in rates {
                refreshPopup.addItem(withTitle: "\(Int(rate.rounded())) Hz")
                refreshPopup.lastItem?.representedObject = rate
            }
            if let current = displayManager.currentRefreshRate(),
               let item = refreshPopup.itemArray.min(by: { left, right in
                   abs(((left.representedObject as? Double) ?? 0) - current)
                   < abs(((right.representedObject as? Double) ?? 0) - current)
               }) {
                refreshPopup.select(item)
            }
        }

        contentStack.addArrangedSubview(section("帧率改变", rows: [
            serviceRow(
                title: "当前优先显示器帧率",
                detail: "优先调整外接显示器；没有外接屏时调整当前内置屏。只使用 macOS 暴露的可用刷新率。",
                controls: [refreshPopup]
            )
        ]))

        contentStack.addArrangedSubview(section("配置保存", rows: [
            serviceRow(
                title: "保存当前为笔记本模式",
                detail: "记录当前分辨率和帧率，之后一键回到这个状态。",
                controls: [button("保存", action: #selector(saveLaptopProfile))]
            ),
            serviceRow(
                title: "保存当前为 4K 显示器模式",
                detail: "记录外接显示器状态，之后一键恢复工作桌面。",
                controls: [button("保存", action: #selector(saveMonitorProfile))]
            )
        ]))
    }

    private func displayStatusView() -> NSView {
        let status = displayManager.status()
        return section("当前状态", rows: [
            serviceRow(
                title: "主显示器：\(status.mainDisplayName)",
                detail: "当前模式：\(status.displayModeName)",
                controls: []
            )
        ])
    }

    private func buildAppExitPage() {
        contentStack.addArrangedSubview(pageTitle("一键退出App模式", subtitle: "记录一组工作 App，需要省电时批量退出，回到工作时按勾选恢复。"))

        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.spacing = 8
        topRow.addArrangedSubview(button("记录当前运行App", action: #selector(recordCurrentApps)))
        topRow.addArrangedSubview(button("退出选中", action: #selector(quitSelectedApps)))
        topRow.addArrangedSubview(button("重新打开选中", action: #selector(reopenSelectedApps)))
        topRow.addArrangedSubview(button("从记录移除", action: #selector(removeSelectedApps)))
        topRow.addArrangedSubview(button("打开配置文件夹", action: #selector(openConfigFolder)))
        topRow.addArrangedSubview(NSView())
        setContentWidth(topRow)
        contentStack.addArrangedSubview(topRow)

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.spacing = 10
        let title = NSTextField(labelWithString: "已记录的 App")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        titleRow.addArrangedSubview(title)
        titleRow.addArrangedSubview(countLabel)
        titleRow.addArrangedSubview(NSView())
        setContentWidth(titleRow)
        contentStack.addArrangedSubview(titleRow)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView
        scrollView.borderType = .bezelBorder
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true
        setContentWidth(scrollView)
        contentStack.addArrangedSubview(scrollView)
    }

    private func buildDesktopPage() {
        contentStack.addArrangedSubview(pageTitle("清空桌面模式", subtitle: "把当前所有普通 App 窗口收起来，进程继续运行，适合看电影或临时把桌面清爽下来。"))
        refreshDesktopWindows()

        contentStack.addArrangedSubview(section("桌面窗口", rows: [
            serviceRow(
                title: "收起所有窗口",
                detail: "隐藏当前所有普通 App 窗口，但不退出进程，不改记录列表，也不会触发未保存文档的关闭提示。",
                controls: [
                    button("一键清空桌面", action: #selector(hideCurrentVisibleApps))
                ]
            ),
            serviceRow(
                title: "打开管理窗口",
                detail: "如果窗口被收起，可以从菜单栏或这里重新打开 Mac模式主窗口。",
                controls: [
                    button("显示窗口", action: #selector(showCurrentWindow))
                ]
            )
        ]))

        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 8

        let title = NSTextField(labelWithString: "当前页面")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        toolbar.addArrangedSubview(title)
        toolbar.addArrangedSubview(windowCountLabel)
        toolbar.addArrangedSubview(NSView())
        toolbar.addArrangedSubview(button("刷新", action: #selector(refreshDesktopWindowList)))
        toolbar.addArrangedSubview(button("定位选中", action: #selector(activateSelectedDesktopWindow)))
        toolbar.addArrangedSubview(button("收起选中", action: #selector(hideSelectedDesktopWindows)))
        setContentWidth(toolbar)
        contentStack.addArrangedSubview(toolbar)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = windowCollectionView
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 340).isActive = true
        setContentWidth(scrollView)
        contentStack.addArrangedSubview(scrollView)
    }

    private func pageTitle(_ title: String, subtitle: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .labelColor

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 2

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        setContentWidth(stack)
        return stack
    }

    private func section(_ title: String, rows: [NSView]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        stack.addArrangedSubview(titleLabel)

        let card = NSStackView()
        card.orientation = .vertical
        card.alignment = .leading
        card.spacing = 0
        card.wantsLayer = true
        card.layer?.cornerRadius = 7
        card.layer?.backgroundColor = cardBackground.cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = dividerColor.cgColor
        for (index, row) in rows.enumerated() {
            card.addArrangedSubview(row)
            if index < rows.count - 1 {
                card.addArrangedSubview(separator())
            }
        }
        setContentWidth(card)
        stack.addArrangedSubview(card)
        setContentWidth(stack)
        return stack
    }

    private func serviceRow(title: String, detail: String, controls: [NSView]) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 16
        row.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.alignment = .left
        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .left
        detailLabel.maximumNumberOfLines = 3

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(detailLabel)
        row.addArrangedSubview(textStack)

        let controlStack = NSStackView()
        controlStack.orientation = .horizontal
        controlStack.spacing = 8
        for control in controls {
            controlStack.addArrangedSubview(control)
        }
        row.addArrangedSubview(controlStack)

        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        controlStack.setContentHuggingPriority(.required, for: .horizontal)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true
        setContentWidth(row)
        return row
    }

    private func separator() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = dividerColor.cgColor
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        setContentWidth(view)
        return view
    }

    private func setContentWidth(_ view: NSView) {
        view.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
    }

    private func spacer(height: CGFloat) -> NSView {
        let view = NSView()
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    private func configureTable() {
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.backgroundColor = NSColor(red: 0.075, green: 0.075, blue: 0.078, alpha: 1)
        tableView.gridColor = NSColor.white.withAlphaComponent(0.05)
        tableView.rowHeight = 46
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(reopenSelectedApps)

        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appColumn.title = "App"
        appColumn.width = 430
        tableView.addTableColumn(appColumn)

        let reopenColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("reopen"))
        reopenColumn.title = "恢复"
        reopenColumn.width = 150
        tableView.addTableColumn(reopenColumn)

        let runningColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("running"))
        runningColumn.title = "状态"
        runningColumn.width = 120
        tableView.addTableColumn(runningColumn)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "退出选中", action: #selector(quitSelectedApps), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "重新打开选中", action: #selector(reopenSelectedApps), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "不重新打开", action: #selector(disableReopenForSelectedApps), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "从记录移除", action: #selector(removeSelectedApps), keyEquivalent: ""))
        menu.items.forEach { $0.target = self }
        tableView.menu = menu
    }

    private func configureWindowCollection() {
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 188, height: 148)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = NSEdgeInsets(top: 2, left: 2, bottom: 14, right: 2)

        windowCollectionView.collectionViewLayout = layout
        windowCollectionView.isSelectable = true
        windowCollectionView.allowsMultipleSelection = true
        windowCollectionView.dataSource = self
        windowCollectionView.delegate = self
        windowCollectionView.backgroundColors = [.clear]
        windowCollectionView.register(
            DesktopWindowItem.self,
            forItemWithIdentifier: DesktopWindowItem.identifier
        )

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "定位选中", action: #selector(activateSelectedDesktopWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "收起选中", action: #selector(hideSelectedDesktopWindows), keyEquivalent: ""))
        menu.items.forEach { $0.target = self }
        windowCollectionView.menu = menu
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        return button
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        apps.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < apps.count, let identifier = tableColumn?.identifier else { return nil }
        let app = apps[row]

        switch identifier.rawValue {
        case "app":
            let cell = NSTableCellView()
            let imageView = NSImageView(image: icon(for: app))
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyUpOrDown

            let label = NSTextField(labelWithString: app.localizedName ?? app.bundleIdentifier ?? "未知 App")
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false

            cell.addSubview(imageView)
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 28),
                imageView.heightAnchor.constraint(equalToConstant: 28),
                label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell

        case "reopen":
            let checkbox = NSButton(checkboxWithTitle: "重新打开", target: self, action: #selector(toggleReopen(_:)))
            checkbox.tag = row
            checkbox.state = app.shouldReopen ? .on : .off
            return checkbox

        case "running":
            let cell = NSTableCellView()
            let status = runningStatus(for: app)
            let label = NSTextField(labelWithString: status.title)
            label.textColor = status.color
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -18),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell

        default:
            return nil
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateCount()
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        desktopWindows.count
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: DesktopWindowItem.identifier,
            for: indexPath
        )
        guard let windowItem = item as? DesktopWindowItem,
              indexPath.item < desktopWindows.count else {
            return item
        }
        windowItem.configure(with: desktopWindows[indexPath.item], icon: icon(for: desktopWindows[indexPath.item]))
        return windowItem
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        didSelectItemsAt indexPaths: Set<IndexPath>
    ) {
        updateDesktopWindowCount()
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        didDeselectItemsAt indexPaths: Set<IndexPath>
    ) {
        updateDesktopWindowCount()
    }

    func tableView(
        _ tableView: NSTableView,
        rowActionsForRow row: Int,
        edge: NSTableView.RowActionEdge
    ) -> [NSTableViewRowAction] {
        guard row < apps.count else { return [] }

        if edge == .trailing {
            let remove = NSTableViewRowAction(style: .destructive, title: "取消记录") { [weak self] _, row in
                self?.remove(row: row)
            }
            let disable = NSTableViewRowAction(style: .regular, title: "不恢复") { [weak self] _, row in
                self?.setShouldReopen(false, row: row)
            }
            disable.backgroundColor = .systemOrange
            return [remove, disable]
        }

        let open = NSTableViewRowAction(style: .regular, title: "打开") { [weak self] _, row in
            self?.reopen(row: row)
        }
        open.backgroundColor = .systemBlue

        let quit = NSTableViewRowAction(style: .regular, title: "退出") { [weak self] _, row in
            self?.quit(row: row)
        }
        quit.backgroundColor = .systemRed
        return [open, quit]
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 {
            removeSelectedApps()
        } else {
            super.keyDown(with: event)
        }
    }

    @objc private func toggleReopen(_ sender: NSButton) {
        guard sender.tag < apps.count else { return }
        apps[sender.tag].shouldReopen = sender.state == .on
        persistApps()
    }

    @objc private func recordCurrentApps() {
        perform("已记录当前运行的App") { try processManager.saveCurrentApps() }
        reload()
    }

    @objc private func quitSelectedApps() {
        let selected = selectedApps()
        markQuitting(selected)
        tableView.reloadData()
        perform("已请求退出选中的App") { try processManager.quit(apps: selected) }
        startQuitRefresh()
    }

    @objc private func reopenSelectedApps() {
        let selected = selectedApps()
        perform("已重新打开选中的App") { try processManager.reopen(apps: selected) }
        tableView.reloadData()
    }

    @objc private func removeSelectedApps() {
        let selectedRows = tableView.selectedRowIndexes
        guard !selectedRows.isEmpty else { return }
        apps = apps.enumerated().filter { !selectedRows.contains($0.offset) }.map(\.element)
        persistApps()
        tableView.reloadData()
        updateCount()
    }

    @objc private func disableReopenForSelectedApps() {
        for index in tableView.selectedRowIndexes where index < apps.count {
            apps[index].shouldReopen = false
        }
        persistApps()
        tableView.reloadData()
    }

    @objc private func hideCurrentVisibleApps() {
        perform("已收起当前所有窗口，进程仍在运行") {
            try processManager.hideCurrentVisibleApps()
        }
        tableView.reloadData()
        refreshDesktopWindows()
    }

    @objc private func refreshDesktopWindowList() {
        refreshDesktopWindows()
    }

    @objc private func hideSelectedDesktopWindows() {
        let selected = selectedDesktopWindows()
        guard !selected.isEmpty else { return }
        perform("已收起选中的页面") {
            try processManager.hide(windows: selected)
        }
        refreshDesktopWindows()
    }

    @objc private func activateSelectedDesktopWindow() {
        guard let window = selectedDesktopWindows().first else { return }
        processManager.activate(window: window)
    }

    private func remove(row: Int) {
        guard row < apps.count else { return }
        apps.remove(at: row)
        persistApps()
        tableView.reloadData()
        updateCount()
    }

    private func setShouldReopen(_ shouldReopen: Bool, row: Int) {
        guard row < apps.count else { return }
        apps[row].shouldReopen = shouldReopen
        persistApps()
        tableView.reloadData()
    }

    private func reopen(row: Int) {
        guard row < apps.count else { return }
        perform("已重新打开 \(apps[row].localizedName ?? "App")") {
            try processManager.reopen(apps: [apps[row]])
        }
        tableView.reloadData()
    }

    private func quit(row: Int) {
        guard row < apps.count else { return }
        markQuitting([apps[row]])
        tableView.reloadData()
        perform("已请求退出 \(apps[row].localizedName ?? "App")") {
            try processManager.quit(apps: [apps[row]])
        }
        startQuitRefresh()
    }

    @objc private func saveLaptopProfile() {
        perform("已保存笔记本模式") { try displayManager.saveProfile(named: .laptop) }
    }

    @objc private func saveMonitorProfile() {
        perform("已保存4K显示器模式") { try displayManager.saveProfile(named: .monitor) }
    }

    @objc private func switchToLaptopMode() {
        perform("已切到笔记本模式") { try displayManager.switchToLaptopMode() }
        renderSelectedMode()
    }

    @objc private func switchToMonitorMode() {
        perform("已切到4K显示器模式") { try displayManager.switchToMonitorMode() }
        renderSelectedMode()
    }

    @objc private func switchToMirrorMode() {
        perform("已切到镜像模式") { try displayManager.switchToMirrorMode() }
        renderSelectedMode()
    }

    @objc private func switchToExtendedMode() {
        perform("已切到扩展模式") { try displayManager.switchToExtendedMode() }
        renderSelectedMode()
    }

    @objc private func changeRefreshRate(_ sender: NSPopUpButton) {
        guard let rate = sender.selectedItem?.representedObject as? Double else { return }
        perform("已切换到 \(Int(rate.rounded()))Hz") {
            try displayManager.setRefreshRate(rate)
        }
        renderSelectedMode()
    }

    @objc private func openConfigFolder() {
        NSWorkspace.shared.open(store.directory)
    }

    @objc private func showCurrentWindow() {
        showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func selectedApps() -> [SavedApp] {
        tableView.selectedRowIndexes.compactMap { index in
            guard index < apps.count else { return nil }
            return apps[index]
        }
    }

    private func selectedDesktopWindows() -> [DesktopWindow] {
        windowCollectionView.selectionIndexPaths.compactMap { indexPath in
            guard indexPath.item < desktopWindows.count else { return nil }
            return desktopWindows[indexPath.item]
        }
    }

    private func refreshDesktopWindows() {
        desktopWindows = processManager.visibleDesktopWindows()
        windowCollectionView.reloadData()
        updateDesktopWindowCount()
    }

    private func updateDesktopWindowCount() {
        let selected = windowCollectionView.selectionIndexPaths.count
        windowCountLabel.stringValue = selected > 0 ? "\(desktopWindows.count) 个，已选 \(selected) 个" : "\(desktopWindows.count) 个"
    }

    private func persistApps() {
        try? processManager.saveProfile(AppProfile(apps: apps))
    }

    private func updateCount() {
        let selected = tableView.selectedRowIndexes.count
        let quitting = apps.filter { quittingAppKeys.contains($0.identityKey) && isRunning($0) }.count
        let selectedText = selected > 0 ? "，已选 \(selected) 个" : ""
        let quittingText = quitting > 0 ? "，正在退出 \(quitting) 个" : ""
        countLabel.stringValue = "\(apps.count) 个\(selectedText)\(quittingText)"
    }

    private func icon(for app: SavedApp) -> NSImage {
        if let bundleIdentifier = app.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let bundlePath = app.bundlePath {
            return NSWorkspace.shared.icon(forFile: bundlePath)
        }
        return NSWorkspace.shared.icon(for: .application)
    }

    private func icon(for window: DesktopWindow) -> NSImage {
        if let bundleIdentifier = window.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let bundlePath = window.bundlePath {
            return NSWorkspace.shared.icon(forFile: bundlePath)
        }
        return NSWorkspace.shared.icon(for: .application)
    }

    private func isRunning(_ savedApp: SavedApp) -> Bool {
        runningKeys(for: savedApp).contains { runningAppKeys.contains($0) }
    }

    private func runningStatus(for app: SavedApp) -> (title: String, color: NSColor) {
        let running = isRunning(app)
        if quittingAppKeys.contains(app.identityKey), running {
            return ("正在退出", .systemOrange)
        }
        return running ? ("运行中", .systemGreen) : ("未运行", .secondaryLabelColor)
    }

    private func markQuitting(_ targetApps: [SavedApp]) {
        let runningKeys = targetApps.filter(isRunning).map(\.identityKey)
        quittingAppKeys.formUnion(runningKeys)
        updateCount()
    }

    private func startQuitRefresh() {
        quitRefreshDeadline = Date().addingTimeInterval(12)
        quitRefreshTimer?.invalidate()
        quitRefreshTimer = Timer.scheduledTimer(
            timeInterval: 0.35,
            target: self,
            selector: #selector(refreshQuittingAppsFromTimer(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func refreshQuittingAppsFromTimer(_ timer: Timer) {
        refreshQuittingApps(timer: timer)
    }

    private func refreshQuittingApps(timer: Timer? = nil) {
        refreshRunningAppKeys()
        removeFinishedQuittingApps()
        tableView.reloadData()
        updateCount()

        let timedOut = quitRefreshDeadline.map { Date() >= $0 } ?? false
        if quittingAppKeys.isEmpty || timedOut {
            if timedOut {
                quittingAppKeys.removeAll()
            }
            timer?.invalidate()
            if timer === quitRefreshTimer {
                quitRefreshTimer = nil
                quitRefreshDeadline = nil
            }
            tableView.reloadData()
            updateCount()
        }
    }

    private func removeFinishedQuittingApps() {
        quittingAppKeys = quittingAppKeys.filter { key in
            apps.contains { $0.identityKey == key && isRunning($0) }
        }
    }

    @objc private func runningApplicationTerminated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        refreshRunningAppKeys()
        if let bundleIdentifier = app.bundleIdentifier {
            quittingAppKeys.remove(bundleIdentifier)
        }
        if let path = app.bundleURL?.path {
            quittingAppKeys.remove(path)
        }
        refreshQuittingApps()
    }

    private func refreshRunningAppKeys() {
        runningAppKeys = Set(NSWorkspace.shared.runningApplications.flatMap { app in
            [app.bundleIdentifier, app.bundleURL?.path].compactMap(\.self)
        })
    }

    private func runningKeys(for app: SavedApp) -> [String] {
        [app.bundleIdentifier, app.bundlePath].compactMap(\.self)
    }

    private func perform(_ success: String, _ work: () throws -> Void) {
        do {
            try work()
            window?.title = "Mac模式 - \(success)"
        } catch {
            showAlert(error.localizedDescription)
        }
    }

    private func showAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Mac模式出错"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

final class FlippedStackView: NSStackView {
    override var isFlipped: Bool {
        true
    }
}

final class FlippedClipView: NSClipView {
    override var isFlipped: Bool {
        true
    }
}

final class ContextSelectingTableView: NSTableView {
    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)
        if clickedRow >= 0, !selectedRowIndexes.contains(clickedRow) {
            selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }
        super.rightMouseDown(with: event)
    }
}

final class ContextSelectingCollectionView: NSCollectionView {
    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let indexPath = indexPathForItem(at: point),
           !selectionIndexPaths.contains(indexPath) {
            selectionIndexPaths = [indexPath]
        }
        super.rightMouseDown(with: event)
    }
}

final class DesktopWindowItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("DesktopWindowItem")

    private let previewView = NSView()
    private let previewImageView = NSImageView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let appLabel = NSTextField(labelWithString: "")
    private let sizeLabel = NSTextField(labelWithString: "")

    override var isSelected: Bool {
        didSet {
            updateSelectionStyle()
        }
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 188, height: 148))
        view.wantsLayer = true
        view.layer?.cornerRadius = 7
        view.layer?.borderWidth = 1

        previewView.wantsLayer = true
        previewView.layer?.cornerRadius = 5
        previewView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.22).cgColor
        previewView.layer?.borderWidth = 1
        previewView.layer?.borderColor = NSColor.white.withAlphaComponent(0.06).cgColor
        previewView.translatesAutoresizingMaskIntoConstraints = false

        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.translatesAutoresizingMaskIntoConstraints = false

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        appLabel.font = .systemFont(ofSize: 11, weight: .medium)
        appLabel.textColor = .secondaryLabelColor
        appLabel.lineBreakMode = .byTruncatingTail
        appLabel.maximumNumberOfLines = 1
        appLabel.translatesAutoresizingMaskIntoConstraints = false

        sizeLabel.font = .systemFont(ofSize: 10, weight: .medium)
        sizeLabel.textColor = NSColor.white.withAlphaComponent(0.48)
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(previewView)
        previewView.addSubview(previewImageView)
        view.addSubview(iconView)
        view.addSubview(titleLabel)
        view.addSubview(appLabel)
        view.addSubview(sizeLabel)

        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            previewView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            previewView.heightAnchor.constraint(equalToConstant: 72),

            previewImageView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 4),
            previewImageView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -4),
            previewImageView.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 4),
            previewImageView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor, constant: -4),

            iconView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            iconView.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 9),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 7),

            appLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            appLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            appLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            sizeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            sizeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            sizeLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])

        updateSelectionStyle()
    }

    func configure(with window: DesktopWindow, icon: NSImage) {
        iconView.image = icon
        previewImageView.image = thumbnail(for: window)
        titleLabel.stringValue = window.displayTitle
        appLabel.stringValue = window.ownerName
        sizeLabel.stringValue = "\(Int(window.bounds.width)) x \(Int(window.bounds.height))"
    }

    private func thumbnail(for window: DesktopWindow) -> NSImage? {
        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.id),
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            return nil
        }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    private func updateSelectionStyle() {
        view.layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.34).cgColor
            : NSColor(red: 0.170, green: 0.170, blue: 0.175, alpha: 1).cgColor
        view.layer?.borderColor = isSelected
            ? NSColor.controlAccentColor.cgColor
            : NSColor.white.withAlphaComponent(0.07).cgColor
    }
}

struct AppError: LocalizedError {
    private let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
