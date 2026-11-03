import Foundation
import CoreData
import SwiftData
import Combine

/// iCloud（CloudKit）同步：
/// 只有用带 iCloud 权限的描述文件签名时才会开启，否则自动退回本地存储。
enum CloudSync {
    static let prefKey = "iCloudSync"

    /// 设置中的开关（默认开启）
    static var enabledInSettings: Bool {
        UserDefaults.standard.object(forKey: prefKey) as? Bool ?? true
    }

    /// 启动时读取的开关值（数据容器只在启动时创建，修改后需重启）
    private(set) static var enabledAtLaunch = true
    /// 本次启动是否真正启用了 CloudKit
    private(set) static var isActive = false

    static let profileEntitlements: [String: Any] = loadProfileEntitlements()

    static var hasCloudKitEntitlement: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        guard let services = profileEntitlements["com.apple.developer.icloud-services"] else { return false }
        if let list = services as? [String] {
            return list.contains("CloudKit") || list.contains("*")
        }
        if let s = services as? String {
            return s == "*" || s == "CloudKit"
        }
        return false
        #endif
    }

    static var isSignedInToICloud: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// UI 自动化测试模式：使用内存数据库
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Memo.self, MemoImage.self])
        if isUITesting {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: config)
        }
        enabledAtLaunch = enabledInSettings
        if enabledAtLaunch && hasCloudKitEntitlement {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            if let container = try? ModelContainer(for: schema, configurations: config) {
                isActive = true
                return container
            }
        }
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            fatalError("无法创建数据存储：\(error)")
        }
    }

    /// 读取安装包内 embedded.mobileprovision 中声明的权限
    private static func loadProfileEntitlements() -> [String: Any] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let raw = String(data: data, encoding: .isoLatin1),
              let start = raw.range(of: "<?xml"),
              let end = raw.range(of: "</plist>", range: start.upperBound..<raw.endIndex),
              let xml = String(raw[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: xml, format: nil) as? [String: Any],
              let ent = plist["Entitlements"] as? [String: Any]
        else { return [:] }
        return ent
    }
}

/// 监听 CloudKit 同步事件，用于在设置页显示同步状态
final class SyncMonitor: ObservableObject {
    static let shared = SyncMonitor()

    @Published var lastSync: Date?
    @Published var lastError: String?
    @Published var inProgress = false

    private var cancellable: AnyCancellable?

    private init() {
        cancellable = NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                self?.handle(note)
            }
    }

    private func handle(_ note: Notification) {
        guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
        else { return }
        if event.endDate == nil {
            inProgress = true
            return
        }
        inProgress = false
        if event.succeeded {
            lastSync = event.endDate
            lastError = nil
        } else {
            lastError = event.error?.localizedDescription
        }
    }
}
