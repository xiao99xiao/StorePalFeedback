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
        info["os_version"] = "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        info["locale"] = Locale.current.identifier
        info["hardware"] = hardwareModel()

        return info
    }

    private static func hardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [UInt8](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        if size > 0 { model = Array(model.prefix(size - 1)) }
        return String(decoding: model, as: UTF8.self)
    }
}
