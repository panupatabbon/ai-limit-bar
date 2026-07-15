import Foundation

public enum L10nKey: String, CaseIterable, Sendable {
    // Settings window
    case settingsTitle, settingsGeneral, settingsDisplay
    case settingsLanguage, settingsTheme
    case themeSystem, themeDark, themeLight
    case showPercent, visibleLimits, headlinePinLabel
    case pinAuto, pinSession, pinWeekly
    case compactRows
    case limitSession, limitWeeklyAll, limitWeeklyModels
    // Popover states
    case hintInstallClaude, hintTokenExpired, offlineLastUpdated, loadingHint, tabComingSoonHint
}

public enum L10n {
    public static func t(_ key: L10nKey, _ lang: AppLanguage) -> String {
        (lang == .en ? en[key] : th[key]) ?? key.rawValue
    }

    private static let en: [L10nKey: String] = [
        .settingsTitle: "Settings",
        .settingsGeneral: "General",
        .settingsDisplay: "Display",
        .settingsLanguage: "Language",
        .settingsTheme: "Theme",
        .themeSystem: "System",
        .themeDark: "Dark",
        .themeLight: "Light",
        .showPercent: "Show % in menu bar",
        .visibleLimits: "Visible limits",
        .headlinePinLabel: "Menu bar % tracks",
        .pinAuto: "Auto (most used)",
        .pinSession: "Session",
        .pinWeekly: "Weekly",
        .compactRows: "Compact rows",
        .limitSession: "Session (5-hour)",
        .limitWeeklyAll: "Weekly (all models)",
        .limitWeeklyModels: "Weekly (per model)",
        .hintInstallClaude: "Install and sign in to Claude Code first — this app reads its quota data.",
        .hintTokenExpired: "Use Claude Code once to renew the token, then this app recovers automatically.",
        .offlineLastUpdated: "Last updated",
        .loadingHint: "Loading quota…",
        .tabComingSoonHint: "Gemini support is coming soon.",
    ]

    private static let th: [L10nKey: String] = [
        .settingsTitle: "ตั้งค่า",
        .settingsGeneral: "ทั่วไป",
        .settingsDisplay: "การแสดงผล",
        .settingsLanguage: "ภาษา",
        .settingsTheme: "ธีม",
        .themeSystem: "ตามระบบ",
        .themeDark: "มืด",
        .themeLight: "สว่าง",
        .showPercent: "แสดง % บนเมนูบาร์",
        .visibleLimits: "ลิมิตที่แสดง",
        .headlinePinLabel: "% บนเมนูบาร์อิงจาก",
        .pinAuto: "อัตโนมัติ (ใช้มากสุด)",
        .pinSession: "รอบ 5 ชั่วโมง",
        .pinWeekly: "รายสัปดาห์",
        .compactRows: "โหมดกะทัดรัด",
        .limitSession: "รอบ 5 ชั่วโมง",
        .limitWeeklyAll: "รายสัปดาห์ (ทุกโมเดล)",
        .limitWeeklyModels: "รายสัปดาห์ (รายโมเดล)",
        .hintInstallClaude: "ติดตั้งและล็อกอิน Claude Code ก่อน — แอปนี้อ่านข้อมูลโควต้าจาก Claude Code",
        .hintTokenExpired: "เปิดใช้ Claude Code หนึ่งครั้งเพื่อต่ออายุ token แล้วแอปจะกลับมาทำงานเอง",
        .offlineLastUpdated: "อัปเดตล่าสุด",
        .loadingHint: "กำลังโหลดโควต้า…",
        .tabComingSoonHint: "รองรับ Gemini เร็วๆ นี้",
    ]
}
