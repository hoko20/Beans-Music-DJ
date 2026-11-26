import SwiftUI

/// 语言选项：2.0.0 起界面仅提供中文，保留该枚举用于日志面板的显示开关。
enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}

/// 兼容旧调用：默认返回中文文案。
func beansLocalized(_ chinese: String, _ english: String) -> String {
    let raw = UserDefaults.standard.string(forKey: "beans.language")
    return raw == AppLanguage.english.rawValue ? english : chinese
}