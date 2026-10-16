import Foundation

enum DeviceMetadata {
    static func collect() -> [String: String] {
        var info: [String: String] = [:]

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            info["app_version"] = version
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            info["app_build"] = build
        }
        if let name = Bundle.main.infoDictionary?["CFBundleName"] as? String {
            info["app_name"] = name
        }

        let os = ProcessInfo.processInfo.operatingSystemVersion
        #if os(iOS)
        let platform = "iOS"
        #else
        let platform = "macOS"
        #endif
        info["os_version"] = "\(platform) \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        info["locale"] = Locale.current.identifier
        info["hardware"] = hardwareModel()

        return info
    }

    private static func hardwareModel() -> String {
        #if os(iOS)
        let key = "hw.machine"
        #else
        let key = "hw.model"
        #endif
        var size = 0
        sysctlbyname(key, nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var model = [UInt8](repeating: 0, count: size)
        sysctlbyname(key, &model, &size, nil, 0)
        if size > 0 { model = Array(model.prefix(size - 1)) }
        return String(decoding: model, as: UTF8.self)
    }
}
