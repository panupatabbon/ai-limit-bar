# ai-limit-bar V1.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the V1.1 feedback round per spec `docs/superpowers/specs/2026-07-15-ai-limit-bar-v1.1-design.md`: composite menu bar item (avatar + smaller % + mini bar), softened palettes, fixed popover anchoring, provider tabs (Claude / Gemini COMING SOON), ACTIVITY 24H section from local transcript scanning, per-provider avatars replacing the picker.

**Architecture:** Same V1 layering. New units: `MenuBarImageBuilder` (pure NSImage compositor), `RelativeTimeFormatter`, `Core/Activity/` (`ActivityScanner` string-scan over `~/.claude/projects/*.jsonl` + `ActivityStore` with 5-min cache), `ProviderTab` in AppSettings. `AvatarID` and the avatar picker are removed; `SpriteLibrary` re-keys by provider id.

**Tech Stack:** unchanged (Swift 6.3 toolchain, v5 language mode, SwiftUI + AppKit, XCTest, zero dependencies).

## Global Constraints

- Baseline: branch `feat/v1-design` at `2cc6a2b` with 51 tests green. Every task ends with full `swift test` green.
- Softened palettes (exact): Dark bg `#14141B`, surface `#1E1E28`, text `#D8D8E4`, pink `#E85D9E`, cyan `#5BC8E8`, ok `#4ADE80`, warn `#E8C547`, critical `#F07171`. Light bg `#F5EFDF`, surface `#EAE2CC`, text `#3A3A42`, pink `#A8487E`, cyan `#2E7D96`, ok `#3B8C5A`, warn `#B0821F`, critical `#C25454`.
- Menu bar composite: 18 pt tall, avatar 16×16 at left, 3 pt gap, right block = % text (Press Start 2P 7 pt) above a 14×3 pt mini bar. No `attributedTitle`, no `baselineOffset`.
- ActivityScanner is read-only over `~/.claude/projects`; file contents never logged or transmitted; must never crash on malformed lines.
- Game labels stay English pixel font (UPDATED, JUST NOW, ACTIVITY 24H, QUOTA, SKILLS, AGENTS, SESSIONS, INSERT CARTRIDGE, NO ACTIVITY, SCANNING…); only the Gemini hint is localized (new key `tabComingSoonHint`).
- Commit after every task on `feat/v1-design`. Never `git add -A`; never stage `.superpowers/` or `AILimitBar.app`.
- TDD for every pure/logic unit; SwiftUI view bodies and AppKit wiring are verified by build + the Task 11 smoke run.

---

### Task 1: Soften palettes

**Files:**
- Modify: `Sources/AILimitBarKit/UI/Retro/RetroTheme.swift`
- Modify: `Tests/AILimitBarKitTests/RetroThemeTests.swift`

**Interfaces:**
- Consumes/produces: `RetroTheme.dark` / `.light` keep their shape; only hex values change to the Global Constraints table.

- [ ] **Step 1: Add failing value-lock test**

Append to `RetroThemeTests`:
```swift
    func testSoftenedPaletteValues() {
        XCTAssertEqual(RetroTheme.dark.background, Color(hex: 0x14141B))
        XCTAssertEqual(RetroTheme.dark.ok, Color(hex: 0x4ADE80))
        XCTAssertEqual(RetroTheme.dark.warn, Color(hex: 0xE8C547))
        XCTAssertEqual(RetroTheme.dark.critical, Color(hex: 0xF07171))
        XCTAssertEqual(RetroTheme.light.background, Color(hex: 0xF5EFDF))
        XCTAssertEqual(RetroTheme.light.ok, Color(hex: 0x3B8C5A))
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter RetroThemeTests`
Expected: FAIL on `testSoftenedPaletteValues` (old values).

- [ ] **Step 3: Replace palette values**

In `RetroTheme.swift` replace both palettes' values:
```swift
    public static let dark = RetroPalette(
        background: Color(hex: 0x14141B),
        surface: Color(hex: 0x1E1E28),
        textPrimary: Color(hex: 0xD8D8E4),
        accentPink: Color(hex: 0xE85D9E),
        accentCyan: Color(hex: 0x5BC8E8),
        ok: Color(hex: 0x4ADE80),
        warn: Color(hex: 0xE8C547),
        critical: Color(hex: 0xF07171))

    public static let light = RetroPalette(
        background: Color(hex: 0xF5EFDF),
        surface: Color(hex: 0xEAE2CC),
        textPrimary: Color(hex: 0x3A3A42),
        accentPink: Color(hex: 0xA8487E),
        accentCyan: Color(hex: 0x2E7D96),
        ok: Color(hex: 0x3B8C5A),
        warn: Color(hex: 0xB0821F),
        critical: Color(hex: 0xC25454))
```

- [ ] **Step 4: Run full tests**

Run: `swift test`
Expected: PASS (52 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/UI/Retro/RetroTheme.swift Tests/AILimitBarKitTests/RetroThemeTests.swift
git commit -m "feat: soften dark/light retro palettes"
```

---

### Task 2: RelativeTimeFormatter

**Files:**
- Create: `Sources/AILimitBarKit/Core/RelativeTimeFormatter.swift`
- Test: `Tests/AILimitBarKitTests/RelativeTimeFormatterTests.swift`

**Interfaces:**
- Produces: `enum RelativeTimeFormatter { static func string(since date: Date, now: Date) -> String }` → `"JUST NOW"` (<60 s), `"5M AGO"`, `"1H AGO"` (exact hours), `"1H 5M AGO"`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AILimitBarKit

final class RelativeTimeFormatterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_784_000_000)
    private func ago(_ s: TimeInterval) -> String {
        RelativeTimeFormatter.string(since: now.addingTimeInterval(-s), now: now)
    }

    func testRelativeStrings() {
        XCTAssertEqual(ago(0), "JUST NOW")
        XCTAssertEqual(ago(59), "JUST NOW")
        XCTAssertEqual(ago(60), "1M AGO")
        XCTAssertEqual(ago(59 * 60), "59M AGO")
        XCTAssertEqual(ago(60 * 60), "1H AGO")
        XCTAssertEqual(ago(65 * 60), "1H 5M AGO")
        XCTAssertEqual(ago(2 * 3600), "2H AGO")
        XCTAssertEqual(ago(-5), "JUST NOW") // clock skew guard
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter RelativeTimeFormatterTests`
Expected: FAIL — `cannot find 'RelativeTimeFormatter' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation

public enum RelativeTimeFormatter {
    public static func string(since date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "JUST NOW" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)M AGO" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)H AGO" : "\(hours)H \(rest)M AGO"
    }
}
```

- [ ] **Step 4: Run to verify pass + full suite**

Run: `swift test --filter RelativeTimeFormatterTests && swift test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/Core/RelativeTimeFormatter.swift Tests/AILimitBarKitTests/RelativeTimeFormatterTests.swift
git commit -m "feat: relative time formatter for UPDATED footer"
```

---

### Task 3: MenuBarImageBuilder

**Files:**
- Create: `Sources/AILimitBarKit/UI/Retro/MenuBarImageBuilder.swift`
- Test: `Tests/AILimitBarKitTests/MenuBarImageBuilderTests.swift`

**Interfaces:**
- Consumes: `SpriteFrame` (has `nsImage(color:pixelSize:)`), `PixelFont.nsFont(size:)`.
- Produces:
  - `MenuBarImageBuilder.Spec { frame: SpriteFrame; percentText: String?; barFraction: Double?; color: NSColor }`
  - `static func layoutWidth(for spec: Spec) -> CGFloat` (pure)
  - `static func image(for spec: Spec) -> NSImage` (size == layoutWidth × 18, non-template)
  - Constants: height 18, avatar 16, gap 3, bar 14×3.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import AppKit
@testable import AILimitBarKit

final class MenuBarImageBuilderTests: XCTestCase {
    private var frame: SpriteFrame { SpriteLibrary.sprite(forProvider: "claude").frames[0] }

    private func spec(text: String?, bar: Double?) -> MenuBarImageBuilder.Spec {
        .init(frame: frame, percentText: text, barFraction: bar, color: .systemGreen)
    }

    func testAvatarOnlyWidth() {
        XCTAssertEqual(MenuBarImageBuilder.layoutWidth(for: spec(text: nil, bar: nil)), 16)
    }

    func testBarOnlyWidth() {
        // 16 avatar + 3 gap + 14 bar
        XCTAssertEqual(MenuBarImageBuilder.layoutWidth(for: spec(text: nil, bar: 0.5)), 33)
    }

    func testTextWidthAtLeastBarWidth() {
        let w = MenuBarImageBuilder.layoutWidth(for: spec(text: "100%", bar: 1.0))
        XCTAssertGreaterThanOrEqual(w, 33)
    }

    func testImageMatchesLayout() {
        let s = spec(text: "42%", bar: 0.42)
        let image = MenuBarImageBuilder.image(for: s)
        XCTAssertEqual(image.size.height, 18)
        XCTAssertEqual(image.size.width, MenuBarImageBuilder.layoutWidth(for: s))
        XCTAssertFalse(image.isTemplate)
    }
}
```
Note: this test uses `SpriteLibrary.sprite(forProvider:)` which does not exist until Task 4. **Tasks 3 and 4 are ordered in the plan but Task 3's test must use the V1 API for now:** replace the `frame` property with `SpriteLibrary.sprite(for: .boo).frames[0]` in this task; Task 4 updates this line when it re-keys the library. (This keeps every task compiling.)

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter MenuBarImageBuilderTests`
Expected: FAIL — `cannot find 'MenuBarImageBuilder' in scope`.

- [ ] **Step 3: Implement**

```swift
import AppKit

/// Renders the whole status-item content (avatar + percent + mini bar)
/// into ONE NSImage so spacing is exact and the button keeps standard
/// menu-bar metrics (fixes the V1 popover-gap problem).
public enum MenuBarImageBuilder {
    public struct Spec {
        public let frame: SpriteFrame
        public let percentText: String?
        public let barFraction: Double?  // 0...1
        public let color: NSColor

        public init(frame: SpriteFrame, percentText: String?,
                    barFraction: Double?, color: NSColor) {
            self.frame = frame
            self.percentText = percentText
            self.barFraction = barFraction
            self.color = color
        }
    }

    static let height: CGFloat = 18
    static let avatarSide: CGFloat = 16
    static let gap: CGFloat = 3
    static let barSize = NSSize(width: 14, height: 3)

    public static func layoutWidth(for spec: Spec) -> CGFloat {
        let right = rightBlockWidth(for: spec)
        return right > 0 ? avatarSide + gap + right : avatarSide
    }

    static func rightBlockWidth(for spec: Spec) -> CGFloat {
        let textWidth = spec.percentText.map { width(of: $0) } ?? 0
        let barWidth: CGFloat = spec.barFraction != nil ? barSize.width : 0
        return max(textWidth, barWidth)
    }

    static func width(of text: String) -> CGFloat {
        let font = PixelFont.nsFont(size: 7)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    public static func image(for spec: Spec) -> NSImage {
        let size = NSSize(width: layoutWidth(for: spec), height: height)
        let image = NSImage(size: size)
        image.lockFocus()

        spec.frame.nsImage(color: spec.color, pixelSize: 1)
            .draw(in: NSRect(x: 0, y: 1, width: avatarSide, height: avatarSide))

        let rightX = avatarSide + gap
        if let text = spec.percentText {
            (text as NSString).draw(
                at: NSPoint(x: rightX, y: 8),
                withAttributes: [.font: PixelFont.nsFont(size: 7),
                                 .foregroundColor: spec.color])
        }
        if let fraction = spec.barFraction {
            let clamped = min(max(fraction, 0), 1)
            let track = NSRect(x: rightX, y: 3,
                               width: barSize.width, height: barSize.height)
            spec.color.withAlphaComponent(0.25).setFill()
            track.fill()
            spec.color.setFill()
            NSRect(x: rightX, y: 3,
                   width: barSize.width * clamped, height: barSize.height).fill()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
```

- [ ] **Step 4: Run to verify pass + full suite**

Run: `swift test --filter MenuBarImageBuilderTests && swift test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/UI/Retro/MenuBarImageBuilder.swift Tests/AILimitBarKitTests/MenuBarImageBuilderTests.swift
git commit -m "feat: composite menu bar image builder (avatar + percent + mini bar)"
```

---

### Task 4: Provider sprites (CLAUDE / GEMINI)

**Files:**
- Modify: `Sources/AILimitBarKit/UI/Retro/Sprite.swift` (Sprite.id becomes `String`)
- Modify: `Sources/AILimitBarKit/UI/Retro/SpriteLibrary.swift` (replace BOO/BUG/BOT with claude/gemini, new `sprite(forProvider:)`)
- Modify: `Tests/AILimitBarKitTests/SpriteTests.swift` (provider-keyed invariants)
- Modify: `Tests/AILimitBarKitTests/MenuBarImageBuilderTests.swift` (switch `frame` property to `sprite(forProvider: "claude")`)
- Modify (call sites so the package keeps compiling): `Sources/AILimitBarKit/UI/Popover/QuotaPopoverView.swift`, `Sources/AILimitBarKit/UI/Settings/SettingsView.swift`, `Sources/AILimitBarKit/App/StatusItemController.swift` — every `SpriteLibrary.sprite(for: settings.avatar)` / `sprite(for: id)` becomes `SpriteLibrary.sprite(forProvider: "claude")`; in `SettingsView` DELETE the whole Avatar section and the `avatarButton` helper (feedback #8: picker removed).

**Interfaces:**
- Produces: `SpriteLibrary.sprite(forProvider id: String) -> Sprite` (`"claude"`, `"gemini"`; unknown id falls back to claude). `Sprite.id: String`. New frames satisfy: 16×16, 4-frame loop `[base, alt, base, blink]`, `frames[0] != frames[1]` with ≥8 differing pixels (visible menu-bar motion — test asserts count).

- [ ] **Step 1: Rewrite the sprite test (failing)**

Replace `Tests/AILimitBarKitTests/SpriteTests.swift` content:
```swift
import XCTest
import AppKit
@testable import AILimitBarKit

final class SpriteTests: XCTestCase {
    private let providers = ["claude", "gemini"]

    func testProviderSpritesAre16x16With4Frames() {
        for id in providers {
            let sprite = SpriteLibrary.sprite(forProvider: id)
            XCTAssertEqual(sprite.id, id)
            XCTAssertEqual(sprite.frames.count, 4)
            XCTAssertEqual(sprite.menuBarFrames.count, 2)
            for (i, frame) in sprite.frames.enumerated() {
                XCTAssertEqual(frame.bitmap.count, 16, "\(id) frame \(i)")
                for row in frame.bitmap { XCTAssertEqual(row.count, 16, "\(id) frame \(i)") }
            }
        }
    }

    func testIdleMotionIsVisible() {
        // base vs alt must differ in at least 8 pixels — V1's subtlety bug.
        for id in providers {
            let sprite = SpriteLibrary.sprite(forProvider: id)
            let a = sprite.frames[0].bitmap.flatMap { $0 }
            let b = sprite.frames[1].bitmap.flatMap { $0 }
            let diff = zip(a, b).filter { $0 != $1 }.count
            XCTAssertGreaterThanOrEqual(diff, 8, "\(id) idle motion too subtle: \(diff) px")
        }
    }

    func testUnknownProviderFallsBackToClaude() {
        XCTAssertEqual(SpriteLibrary.sprite(forProvider: "unknown").id, "claude")
    }

    func testNSImageRendering() {
        let frame = SpriteLibrary.sprite(forProvider: "claude").frames[0]
        let image = frame.nsImage(color: .systemGreen, pixelSize: 1)
        XCTAssertEqual(image.size, NSSize(width: 16, height: 16))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter SpriteTests`
Expected: FAIL — `sprite(forProvider:)` not found.

- [ ] **Step 3: Implement sprites**

`Sprite.swift`: change `public let id: AvatarID` → `public let id: String` and the init parameter accordingly. (`AvatarID` itself is removed in Task 5.)

`SpriteLibrary.swift` — replace entire body:
```swift
import Foundation

public enum SpriteLibrary {
    public static func sprite(forProvider id: String) -> Sprite {
        switch id {
        case "gemini": return gemini
        default: return claude
        }
    }

    // CLAUDE — original spark-creature. alt: body bobs up 1px, side sparks flare.
    static let claude = Sprite(
        id: "claude",
        base: SpriteFrame(rows: [
            "................",
            ".......##.......",
            "......####......",
            "..#...####...#..",
            "...#.######.#...",
            "....########....",
            "...##.####.##...",
            "...##########...",
            "....########....",
            ".....######.....",
            "....##.##.##....",
            "....#..##..#....",
            "................",
            "................",
            "................",
            "................",
        ]),
        alt: SpriteFrame(rows: [
            "................",
            "......####......",
            "..#...####...#..",
            "...#.######.#...",
            "....########....",
            "...##.####.##...",
            "...##########...",
            "....########....",
            ".....######.....",
            "....##.##.##....",
            "...#...##...#...",
            "................",
            "................",
            "................",
            "................",
            "................",
        ]),
        blink: SpriteFrame(rows: [
            "................",
            ".......##.......",
            "......####......",
            "..#...####...#..",
            "...#.######.#...",
            "....########....",
            "...##########...",
            "...##########...",
            "....########....",
            ".....######.....",
            "....##.##.##....",
            "....#..##..#....",
            "................",
            "................",
            "................",
            "................",
        ]))

    // GEMINI — original twin stars. alt: heights swap.
    static let gemini = Sprite(
        id: "gemini",
        base: SpriteFrame(rows: [
            "................",
            "...#............",
            "..###...........",
            ".#####..........",
            "..###......#....",
            "...#......###...",
            ".........#####..",
            "..........###...",
            "...........#....",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
        ]),
        alt: SpriteFrame(rows: [
            "................",
            "...........#....",
            "..........###...",
            ".........#####..",
            "...#......###...",
            "..###......#....",
            ".#####..........",
            "..###...........",
            "...#............",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
        ]),
        blink: SpriteFrame(rows: [
            "................",
            "................",
            "...#............",
            "..###...........",
            "...#.......#....",
            "..........###...",
            "...........#....",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
        ]))
}
```
Every row string must be EXACTLY 16 characters — the preconditions and tests enforce it; count carefully.

- [ ] **Step 4: Update call sites**

In `QuotaPopoverView.swift` header: `SpriteLibrary.sprite(for: settings.avatar)` → `SpriteLibrary.sprite(forProvider: "claude")`.
In `StatusItemController.swift` render(): `SpriteLibrary.sprite(for: settings.avatar)` → `SpriteLibrary.sprite(forProvider: "claude")`.
In `SettingsView.swift`: delete the Avatar `section(...)` block and the `avatarButton(_:_:)` helper entirely.
In `MenuBarImageBuilderTests.swift`: `frame` property now reads `SpriteLibrary.sprite(forProvider: "claude").frames[0]`.

- [ ] **Step 5: Run full suite**

Run: `swift test`
Expected: PASS. If a sprite precondition trips, a row is not 16 chars — fix the transcription, keep the shape.

- [ ] **Step 6: Commit**

```bash
git add Sources/AILimitBarKit/UI Tests/AILimitBarKitTests/SpriteTests.swift Tests/AILimitBarKitTests/MenuBarImageBuilderTests.swift Sources/AILimitBarKit/App/StatusItemController.swift
git commit -m "feat: provider avatars CLAUDE/GEMINI replace picker sprites"
```

---

### Task 5: AppSettings — remove avatar, add ProviderTab

**Files:**
- Modify: `Sources/AILimitBarKit/Core/AppSettings.swift`
- Modify: `Tests/AILimitBarKitTests/AppSettingsTests.swift`

**Interfaces:**
- Removes: `AvatarID` enum, `AppSettings.avatar` (stored key ignored — no migration per spec §6).
- Produces: `enum ProviderTab: String, CaseIterable, Sendable { case claude, gemini }` and persisted `AppSettings.selectedTab: ProviderTab` (default `.claude`, key `"selectedTab"`).

- [ ] **Step 1: Update tests (failing)**

In `AppSettingsTests`: delete the `avatar` assertions from `testDefaults`/`testPersistsAcrossInstances`; add:
```swift
    func testSelectedTabDefaultsAndPersists() {
        let s1 = AppSettings(defaults: defaults)
        XCTAssertEqual(s1.selectedTab, .claude)
        s1.selectedTab = .gemini
        XCTAssertEqual(AppSettings(defaults: defaults).selectedTab, .gemini)
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter AppSettingsTests`
Expected: FAIL — `selectedTab` not found.

- [ ] **Step 3: Implement**

In `AppSettings.swift`: delete `public enum AvatarID…` and the `avatar` property + its init line; add:
```swift
public enum ProviderTab: String, CaseIterable, Sendable { case claude, gemini }
```
and in the class:
```swift
    public var selectedTab: ProviderTab { didSet { defaults.set(selectedTab.rawValue, forKey: "selectedTab") } }
```
init: `selectedTab = ProviderTab(rawValue: defaults.string(forKey: "selectedTab") ?? "") ?? .claude`

- [ ] **Step 4: Full suite**

Run: `swift test`
Expected: PASS (no other file references `AvatarID` after Task 4).

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/Core/AppSettings.swift Tests/AILimitBarKitTests/AppSettingsTests.swift
git commit -m "feat: provider tab setting; remove avatar picker setting"
```

---

### Task 6: L10n — tabComingSoonHint

**Files:**
- Modify: `Sources/AILimitBarKit/Core/L10n.swift`
- Modify: `Tests/AILimitBarKitTests/L10nTests.swift`

- [ ] **Step 1: Add failing assertion**

Append to `L10nTests.testSample`:
```swift
        XCTAssertEqual(L10n.t(.tabComingSoonHint, .en), "Gemini support is coming soon.")
        XCTAssertEqual(L10n.t(.tabComingSoonHint, .th), "รองรับ Gemini เร็วๆ นี้")
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter L10nTests`
Expected: FAIL — `tabComingSoonHint` not found.

- [ ] **Step 3: Implement**

Add case `tabComingSoonHint` to `L10nKey`; add to `en`: `.tabComingSoonHint: "Gemini support is coming soon."`; to `th`: `.tabComingSoonHint: "รองรับ Gemini เร็วๆ นี้"`. (The completeness test then covers it automatically.)

- [ ] **Step 4: Run + full suite**

Run: `swift test --filter L10nTests && swift test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/Core/L10n.swift Tests/AILimitBarKitTests/L10nTests.swift
git commit -m "feat: localized Gemini coming-soon hint"
```

---

### Task 7: ActivityScanner

**Files:**
- Create: `Sources/AILimitBarKit/Core/Activity/ActivityModels.swift`
- Create: `Sources/AILimitBarKit/Core/Activity/ActivityScanner.swift`
- Test: `Tests/AILimitBarKitTests/ActivityScannerTests.swift`

**Interfaces:**
- Produces:
  - `struct ActivityCount: Equatable, Sendable { let name: String; let count: Int }`
  - `struct ActivitySummary: Equatable, Sendable { let topSkills: [ActivityCount]; let topAgents: [ActivityCount]; let sessionCount: Int; let scannedAt: Date }`
  - `enum ActivityEvent: Equatable { case skill(String), agent(String) }`
  - `struct ActivityScanner { init(root: URL, window: TimeInterval = 86_400, now: @escaping @Sendable () -> Date = { Date() }); func scan() -> ActivitySummary; static func parseLine(_ line: Substring) -> ActivityEvent?; static var defaultRoot: URL }`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AILimitBarKit

final class ActivityScannerTests: XCTestCase {
    func testParseLine() {
        XCTAssertEqual(
            ActivityScanner.parseLine(#"{"type":"x","name":"Skill","input":{"skill":"superpowers:brainstorming"}}"#),
            .skill("superpowers:brainstorming"))
        XCTAssertEqual(
            ActivityScanner.parseLine(#"{"input":{"subagent_type":"general-purpose","prompt":"hi"}}"#),
            .agent("general-purpose"))
        XCTAssertNil(ActivityScanner.parseLine(#"{"name":"Skills","input":{"skill":"nope"}}"#)) // near-miss
        XCTAssertNil(ActivityScanner.parseLine("total garbage {{{"))
        XCTAssertNil(ActivityScanner.parseLine(""))
        XCTAssertNil(ActivityScanner.parseLine(#"{"name":"Skill","input":{}}"#)) // no skill value
    }

    func testScanCountsAndWindow() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("activity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fresh1 = dir.appendingPathComponent("a.jsonl")
        try [
            #"{"name":"Skill","input":{"skill":"alpha"}}"#,
            #"{"name":"Skill","input":{"skill":"alpha"}}"#,
            #"{"name":"Skill","input":{"skill":"beta"}}"#,
            #"{"input":{"subagent_type":"general-purpose"}}"#,
            "garbage line",
        ].joined(separator: "\n").write(to: fresh1, atomically: true, encoding: .utf8)

        let fresh2 = dir.appendingPathComponent("b.jsonl")
        try [
            #"{"name":"Skill","input":{"skill":"alpha"}}"#,
            #"{"input":{"subagent_type":"general-purpose"}}"#,
            #"{"input":{"subagent_type":"reviewer"}}"#,
        ].joined(separator: "\n").write(to: fresh2, atomically: true, encoding: .utf8)

        let stale = dir.appendingPathComponent("old.jsonl")
        try #"{"name":"Skill","input":{"skill":"ghost"}}"#.write(to: stale, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-3 * 86_400)],
            ofItemAtPath: stale.path)

        let notJsonl = dir.appendingPathComponent("skip.txt")
        try #"{"name":"Skill","input":{"skill":"txt"}}"#.write(to: notJsonl, atomically: true, encoding: .utf8)

        let summary = ActivityScanner(root: dir).scan()
        XCTAssertEqual(summary.sessionCount, 2)
        XCTAssertEqual(summary.topSkills, [ActivityCount(name: "alpha", count: 3),
                                           ActivityCount(name: "beta", count: 1)])
        XCTAssertEqual(summary.topAgents, [ActivityCount(name: "general-purpose", count: 2),
                                           ActivityCount(name: "reviewer", count: 1)])
    }

    func testScanEmptyDirectory() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("activity-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let summary = ActivityScanner(root: dir).scan()
        XCTAssertEqual(summary.sessionCount, 0)
        XCTAssertTrue(summary.topSkills.isEmpty)
        XCTAssertTrue(summary.topAgents.isEmpty)
    }

    func testScanMissingRootDoesNotCrash() {
        let summary = ActivityScanner(root: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)")).scan()
        XCTAssertEqual(summary.sessionCount, 0)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter ActivityScannerTests`
Expected: FAIL — `cannot find 'ActivityScanner' in scope`.

- [ ] **Step 3: Implement**

`ActivityModels.swift`:
```swift
import Foundation

public struct ActivityCount: Equatable, Sendable {
    public let name: String
    public let count: Int
    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

public struct ActivitySummary: Equatable, Sendable {
    public let topSkills: [ActivityCount]
    public let topAgents: [ActivityCount]
    public let sessionCount: Int
    public let scannedAt: Date
    public init(topSkills: [ActivityCount], topAgents: [ActivityCount],
                sessionCount: Int, scannedAt: Date) {
        self.topSkills = topSkills
        self.topAgents = topAgents
        self.sessionCount = sessionCount
        self.scannedAt = scannedAt
    }
}

public enum ActivityEvent: Equatable, Sendable {
    case skill(String)
    case agent(String)
}
```

`ActivityScanner.swift`:
```swift
import Foundation

/// Read-only, best-effort scan of Claude Code transcripts for the last-24h
/// activity section. String-search based (the JSONL format is undocumented);
/// malformed input is skipped, never fatal. File contents are never logged.
public struct ActivityScanner: Sendable {
    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    let root: URL
    let window: TimeInterval
    let now: @Sendable () -> Date

    public init(root: URL = ActivityScanner.defaultRoot,
                window: TimeInterval = 86_400,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.root = root
        self.window = window
        self.now = now
    }

    public func scan() -> ActivitySummary {
        let cutoff = now().addingTimeInterval(-window)
        var skills: [String: Int] = [:]
        var agents: [String: Int] = [:]
        var sessions = 0

        let files = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])

        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "jsonl",
                  let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                      .contentModificationDate,
                  modified >= cutoff,
                  let content = try? String(contentsOf: url, encoding: .utf8)
            else { continue }
            sessions += 1
            for line in content.split(separator: "\n") {
                switch Self.parseLine(line) {
                case .skill(let name): skills[name, default: 0] += 1
                case .agent(let name): agents[name, default: 0] += 1
                case nil: break
                }
            }
        }

        return ActivitySummary(
            topSkills: top3(skills), topAgents: top3(agents),
            sessionCount: sessions, scannedAt: now())
    }

    private func top3(_ counts: [String: Int]) -> [ActivityCount] {
        counts.map { ActivityCount(name: $0.key, count: $0.value) }
            .sorted { ($0.count, $1.name) > ($1.count, $0.name) }
            .prefix(3)
            .map { $0 }
    }

    public static func parseLine(_ line: Substring) -> ActivityEvent? {
        if line.contains(#""name":"Skill","#),
           let name = value(after: #""skill":""#, in: line) {
            return .skill(name)
        }
        if let name = value(after: #""subagent_type":""#, in: line) {
            return .agent(name)
        }
        return nil
    }

    private static func value(after marker: String, in line: Substring) -> String? {
        guard let start = line.range(of: marker)?.upperBound,
              let end = line[start...].firstIndex(of: "\"")
        else { return nil }
        let name = line[start..<end]
        return name.isEmpty ? nil : String(name)
    }
}
```
Note the sorting comparator: `($0.count, $1.name) > ($1.count, $0.name)` sorts by count descending, then name ascending — deterministic for the test.

- [ ] **Step 4: Run to verify pass + full suite**

Run: `swift test --filter ActivityScannerTests && swift test`
Expected: PASS. If `testParseLine`'s empty-skill case fails, check `value(after:)` returns nil for empty captures.

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/Core/Activity Tests/AILimitBarKitTests/ActivityScannerTests.swift
git commit -m "feat: last-24h activity scanner over local Claude Code transcripts"
```

---

### Task 8: ActivityStore

**Files:**
- Create: `Sources/AILimitBarKit/Core/Activity/ActivityStore.swift`
- Test: `Tests/AILimitBarKitTests/ActivityStoreTests.swift`

**Interfaces:**
- Consumes: `ActivityScanner`, `ActivitySummary`.
- Produces (`@MainActor @Observable`): `ActivityStore { init(scanner: ActivityScanner, now: @escaping () -> Date = { Date() }); private(set) var summary: ActivitySummary?; private(set) var isScanning: Bool; func refresh() async; func refreshIfStale(olderThan: TimeInterval = 300); func isStale(olderThan: TimeInterval) -> Bool }`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AILimitBarKit

@MainActor
final class ActivityStoreTests: XCTestCase {
    private func makeStore(dir: URL, now: @escaping () -> Date) -> ActivityStore {
        ActivityStore(scanner: ActivityScanner(root: dir), now: now)
    }

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testRefreshPopulatesSummary() async throws {
        let dir = try tempDir()
        try #"{"name":"Skill","input":{"skill":"alpha"}}"#
            .write(to: dir.appendingPathComponent("s.jsonl"), atomically: true, encoding: .utf8)
        let store = makeStore(dir: dir, now: { Date() })
        XCTAssertNil(store.summary)
        await store.refresh()
        XCTAssertEqual(store.summary?.topSkills.first, ActivityCount(name: "alpha", count: 1))
        XCTAssertFalse(store.isScanning)
    }

    func testStaleGate() async throws {
        let dir = try tempDir()
        var currentTime = Date(timeIntervalSince1970: 1_784_000_000)
        let store = makeStore(dir: dir, now: { currentTime })
        XCTAssertTrue(store.isStale(olderThan: 300)) // no summary yet
        await store.refresh()
        XCTAssertFalse(store.isStale(olderThan: 300)) // fresh
        currentTime = currentTime.addingTimeInterval(301)
        XCTAssertTrue(store.isStale(olderThan: 300)) // aged out
    }
}
```
Note: `ActivityScanner`'s `now` defaults to `Date()` inside the scanner; the store's injected `now` governs only staleness. In `testStaleGate` the summary's `scannedAt` comes from the scanner's real clock while staleness compares against the injected clock — to keep the test deterministic, `ActivityStore.isStale` must compare against the summary's `scannedAt` recorded via the STORE's clock at refresh completion (store keeps its own `lastRefreshed: Date?` stamped with its injected `now()`), not the scanner's `scannedAt`. Implement exactly that.

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter ActivityStoreTests`
Expected: FAIL — `cannot find 'ActivityStore' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation
import Observation

@MainActor
@Observable
public final class ActivityStore {
    public private(set) var summary: ActivitySummary?
    public private(set) var isScanning = false

    private let scanner: ActivityScanner
    private let now: () -> Date
    private var lastRefreshed: Date?

    public init(scanner: ActivityScanner = ActivityScanner(),
                now: @escaping () -> Date = { Date() }) {
        self.scanner = scanner
        self.now = now
    }

    public func isStale(olderThan seconds: TimeInterval) -> Bool {
        guard let lastRefreshed else { return true }
        return now().timeIntervalSince(lastRefreshed) >= seconds
    }

    public func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        let scanner = self.scanner
        let result = await Task.detached(priority: .utility) { scanner.scan() }.value
        summary = result
        lastRefreshed = now()
        isScanning = false
    }

    public func refreshIfStale(olderThan seconds: TimeInterval = 300) {
        guard isStale(olderThan: seconds) else { return }
        Task { await refresh() }
    }
}
```

- [ ] **Step 4: Run to verify pass + full suite**

Run: `swift test --filter ActivityStoreTests && swift test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/Core/Activity/ActivityStore.swift Tests/AILimitBarKitTests/ActivityStoreTests.swift
git commit -m "feat: activity store with 5-minute cache and background scan"
```

---

### Task 9: Popover restructure (tabs + sections + activity + footer)

**Files:**
- Modify: `Sources/AILimitBarKit/UI/Popover/QuotaPopoverView.swift` (full rewrite below)
- Test: `Tests/AILimitBarKitTests/PopoverLogicTests.swift` (unchanged — `visibleLimits` keeps its contract; verify still passing)

**Interfaces:**
- Consumes: `QuotaStore`, `AppSettings` (now with `selectedTab`), `ActivityStore`, `L10n`, `RetroTheme`, `PixelFont`, `LimitRowView`, `AvatarSpriteView`, `SpriteLibrary.sprite(forProvider:)`, `RelativeTimeFormatter`.
- Produces: `QuotaPopoverView { init(store: QuotaStore, settings: AppSettings, activity: ActivityStore, onOpenSettings: @escaping () -> Void, onQuit: @escaping () -> Void) }`; static `visibleLimits` unchanged.

- [ ] **Step 1: Rewrite QuotaPopoverView**

Replace file content:
```swift
import SwiftUI

public struct QuotaPopoverView: View {
    @Environment(\.colorScheme) private var colorScheme
    let store: QuotaStore
    @Bindable var settings: AppSettings
    let activity: ActivityStore
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    public init(store: QuotaStore, settings: AppSettings, activity: ActivityStore,
                onOpenSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.activity = activity
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public static func visibleLimits(_ snapshot: QuotaSnapshot?, settings: AppSettings) -> [QuotaLimit] {
        (snapshot?.limits ?? []).filter { settings.isVisible($0.kind) }
    }

    private var palette: RetroPalette {
        RetroTheme.palette(settings.theme, systemIsDark: colorScheme == .dark)
    }

    public var body: some View {
        let palette = self.palette
        VStack(alignment: .leading, spacing: 14) {
            tabBar(palette)
            switch settings.selectedTab {
            case .claude: claudeTab(palette)
            case .gemini: geminiTab(palette)
            }
            footer(palette)
        }
        .padding(16)
        .frame(width: 300)
        .background(palette.background)
    }

    // MARK: Tabs

    @ViewBuilder
    private func tabBar(_ palette: RetroPalette) -> some View {
        HStack(spacing: 6) {
            ForEach(ProviderTab.allCases, id: \.self) { tab in
                Button {
                    settings.selectedTab = tab
                } label: {
                    Text(tab.rawValue.uppercased())
                        .font(PixelFont.swiftUI(size: 8))
                        .foregroundStyle(settings.selectedTab == tab
                                         ? palette.background : palette.textPrimary.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(settings.selectedTab == tab ? palette.accentCyan : palette.surface)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: Claude tab

    @ViewBuilder
    private func claudeTab(_ palette: RetroPalette) -> some View {
        header(palette)
        sectionHeader("QUOTA", palette)
        quotaContent(palette)
        sectionHeader("ACTIVITY 24H", palette)
        activitySection(palette)
    }

    @ViewBuilder
    private func header(_ palette: RetroPalette) -> some View {
        HStack {
            Text(store.currentSnapshot?.planName ?? "AI QUOTA")
                .font(PixelFont.swiftUI(size: 9))
                .foregroundStyle(palette.accentCyan)
            Spacer()
            AvatarSpriteView(sprite: SpriteLibrary.sprite(forProvider: "claude"),
                             color: headlineColor(palette), pixelScale: 2)
        }
    }

    private func headlineColor(_ palette: RetroPalette) -> Color {
        guard let headline = store.headlineLimit(pin: settings.headlinePin) else {
            return palette.textPrimary.opacity(0.5)
        }
        return RetroTheme.color(for: Severity(percent: headline.percentUsed), in: palette)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, _ palette: RetroPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(PixelFont.swiftUI(size: 7))
                .foregroundStyle(palette.accentPink)
            Rectangle()
                .fill(palette.textPrimary.opacity(0.2))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func quotaContent(_ palette: RetroPalette) -> some View {
        switch store.state {
        case .loading:
            stateScreen("LOADING", hint: L10n.t(.loadingHint, settings.language), palette: palette)
        case .credentialsMissing:
            stateScreen("INSERT COIN", hint: L10n.t(.hintInstallClaude, settings.language), palette: palette)
        case .tokenExpired:
            stateScreen("TOKEN EXPIRED", hint: L10n.t(.hintTokenExpired, settings.language), palette: palette)
        case .ready, .offline:
            limitList(palette)
            if case .offline(let last) = store.state {
                offlineBadge(last, palette: palette)
            }
        }
    }

    @ViewBuilder
    private func limitList(_ palette: RetroPalette) -> some View {
        let limits = Self.visibleLimits(store.currentSnapshot, settings: settings)
        if limits.isEmpty {
            stateScreen("NO DATA", hint: "", palette: palette)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(limits.enumerated()), id: \.offset) { _, limit in
                    LimitRowView(limit: limit, palette: palette, compact: settings.compactRows)
                }
            }
        }
    }

    @ViewBuilder
    private func stateScreen(_ title: String, hint: String, palette: RetroPalette) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(PixelFont.swiftUI(size: 12))
                .foregroundStyle(palette.accentPink)
            if !hint.isEmpty {
                Text(hint)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(palette.textPrimary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func offlineBadge(_ last: QuotaSnapshot?, palette: RetroPalette) -> some View {
        HStack(spacing: 6) {
            Text("OFFLINE")
                .font(PixelFont.swiftUI(size: 7))
                .foregroundStyle(palette.warn)
            if let last {
                Text(RelativeTimeFormatter.string(since: last.fetchedAt, now: Date()))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(palette.textPrimary.opacity(0.6))
            }
        }
    }

    // MARK: Activity

    @ViewBuilder
    private func activitySection(_ palette: RetroPalette) -> some View {
        if let summary = activity.summary {
            if summary.topSkills.isEmpty && summary.topAgents.isEmpty && summary.sessionCount == 0 {
                Text("NO ACTIVITY")
                    .font(PixelFont.swiftUI(size: 8))
                    .foregroundStyle(palette.textPrimary.opacity(0.5))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if !summary.topSkills.isEmpty {
                        activityGroup("SKILLS", items: summary.topSkills, palette: palette)
                    }
                    if !summary.topAgents.isEmpty {
                        activityGroup("AGENTS", items: summary.topAgents, palette: palette)
                    }
                    Text("SESSIONS \(summary.sessionCount)")
                        .font(PixelFont.swiftUI(size: 7))
                        .foregroundStyle(palette.textPrimary.opacity(0.8))
                }
            }
        } else {
            Text(activity.isScanning ? "SCANNING…" : "NO ACTIVITY")
                .font(PixelFont.swiftUI(size: 8))
                .foregroundStyle(palette.textPrimary.opacity(0.5))
        }
    }

    @ViewBuilder
    private func activityGroup(_ title: String, items: [ActivityCount],
                               palette: RetroPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(PixelFont.swiftUI(size: 7))
                .foregroundStyle(palette.accentCyan)
            ForEach(items, id: \.name) { item in
                HStack {
                    Text(item.name)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(palette.textPrimary)
                    Spacer()
                    Text("×\(item.count)")
                        .font(PixelFont.swiftUI(size: 7))
                        .foregroundStyle(palette.textPrimary.opacity(0.7))
                }
            }
        }
    }

    // MARK: Gemini tab

    @ViewBuilder
    private func geminiTab(_ palette: RetroPalette) -> some View {
        VStack(spacing: 12) {
            AvatarSpriteView(sprite: SpriteLibrary.sprite(forProvider: "gemini"),
                             color: palette.accentCyan, pixelScale: 3)
            Text("INSERT CARTRIDGE")
                .font(PixelFont.swiftUI(size: 11))
                .foregroundStyle(palette.accentPink)
            Text(L10n.t(.tabComingSoonHint, settings.language))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(palette.textPrimary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: Footer

    @ViewBuilder
    private func footer(_ palette: RetroPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(palette.textPrimary.opacity(0.2))
                .frame(height: 1)
            HStack {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(updatedLabel(now: context.date))
                        .font(PixelFont.swiftUI(size: 6))
                        .foregroundStyle(palette.textPrimary.opacity(0.6))
                }
                Spacer()
                Button(action: onOpenSettings) {
                    Text("⚙ SETTINGS")
                        .font(PixelFont.swiftUI(size: 7))
                        .foregroundStyle(palette.textPrimary.opacity(0.7))
                }
                .buttonStyle(.plain)
                Button(action: onQuit) {
                    Text("⏻ QUIT")
                        .font(PixelFont.swiftUI(size: 7))
                        .foregroundStyle(palette.textPrimary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func updatedLabel(now: Date) -> String {
        guard let fetched = store.currentSnapshot?.fetchedAt else { return "UPDATED --" }
        return "UPDATED " + RelativeTimeFormatter.string(since: fetched, now: now)
    }
}
```
(The `onQuit` parameter already exists in V1's fixed version — keep its call-site wiring; this rewrite keeps both closures.)

- [ ] **Step 2: Build + targeted tests**

`StatusItemController` still calls the old initializer (without `activity:`) — Task 10 fixes the call site. To keep this task compiling, ALSO update the call in `StatusItemController.start()` minimally now:
```swift
        popover.contentViewController = NSHostingController(
            rootView: QuotaPopoverView(store: store, settings: settings,
                                       activity: activityStore) { [weak self] in
                self?.popover?.performClose(nil)
                self?.settingsWindow.show()
            } onQuit: {
                NSApp.terminate(nil)
            })
```
and add to `StatusItemController`: `private let activityStore: ActivityStore` + init parameter `activity: ActivityStore` (stored), and in `AppDelegate.applicationDidFinishLaunching` create `let activity = ActivityStore()` and pass `StatusItemController(store: store, settings: settings, activity: activity)`.

Run: `swift build && swift test --filter PopoverLogicTests && swift test`
Expected: all PASS.

- [ ] **Step 3: Commit**

```bash
git add Sources/AILimitBarKit/UI/Popover/QuotaPopoverView.swift Sources/AILimitBarKit/App/StatusItemController.swift Sources/AILimitBarKit/App/AppDelegate.swift
git commit -m "feat: popover tabs, activity section, sectioned layout, updated footer"
```

---

### Task 10: Status item composite + activity wiring + anchor check

**Files:**
- Modify: `Sources/AILimitBarKit/App/StatusItemController.swift`
- Modify: `Tests/AILimitBarKitTests/StatusItemLogicTests.swift`

**Interfaces:**
- `render()` now builds `MenuBarImageBuilder.Spec` and sets ONLY `button.image` (no `attributedTitle`).
- New pure static: `menuBarSpec(headline: QuotaLimit?, state: QuotaStore.State, showPercent: Bool, frame: SpriteFrame, palette: RetroPalette) -> MenuBarImageBuilder.Spec` — reuses `menuBarTitle`/`menuBarColor`; `percentText = title.isEmpty ? nil : title`; `barFraction = (ready/offline with headline) ? min(max(headline.percentUsed/100, 0), 1) : nil`.
- `togglePopover()` additionally calls `activityStore.refreshIfStale()` when opening.

- [ ] **Step 1: Add failing spec test**

Append to `StatusItemLogicTests`:
```swift
    func testMenuBarSpec() {
        let frame = SpriteLibrary.sprite(forProvider: "claude").menuBarFrames[0]
        let palette = RetroTheme.dark

        let ready = StatusItemController.menuBarSpec(
            headline: headline, state: .ready(snap), showPercent: true,
            frame: frame, palette: palette)
        XCTAssertEqual(ready.percentText, "58%")
        XCTAssertEqual(ready.barFraction, 0.58)

        let hidden = StatusItemController.menuBarSpec(
            headline: headline, state: .ready(snap), showPercent: false,
            frame: frame, palette: palette)
        XCTAssertNil(hidden.percentText)
        XCTAssertEqual(hidden.barFraction, 0.58) // bar still shown when % hidden

        let expired = StatusItemController.menuBarSpec(
            headline: nil, state: .tokenExpired, showPercent: true,
            frame: frame, palette: palette)
        XCTAssertEqual(expired.percentText, "--")
        XCTAssertNil(expired.barFraction)
    }
```
(`barFraction` compare: use `XCTAssertEqual(ready.barFraction ?? -1, 0.58, accuracy: 0.001)` if Double equality flakes.)

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter StatusItemLogicTests`
Expected: FAIL — `menuBarSpec` not found.

- [ ] **Step 3: Implement**

In `StatusItemController`:
```swift
    public static func menuBarSpec(headline: QuotaLimit?, state: QuotaStore.State,
                                   showPercent: Bool, frame: SpriteFrame,
                                   palette: RetroPalette) -> MenuBarImageBuilder.Spec {
        let title = menuBarTitle(headline: headline, state: state, showPercent: showPercent)
        let color = menuBarColor(headline: headline, state: state, palette: palette)
        let bar: Double?
        switch state {
        case .ready, .offline:
            bar = headline.map { min(max($0.percentUsed / 100, 0), 1) }
        default:
            bar = nil
        }
        return MenuBarImageBuilder.Spec(
            frame: frame,
            percentText: title.isEmpty ? nil : title,
            barFraction: bar,
            color: color)
    }
```
Replace the body of `render()`:
```swift
    private func render() {
        guard let button = statusItem?.button else { return }
        let palette = RetroTheme.palette(settings.theme, systemIsDark: systemIsDark)
        let headline = store.headlineLimit(pin: settings.headlinePin)
        let frames = SpriteLibrary.sprite(forProvider: "claude").menuBarFrames
        let spec = Self.menuBarSpec(
            headline: headline, state: store.state,
            showPercent: settings.showPercentInMenuBar,
            frame: frames[frameIndex % frames.count], palette: palette)
        button.image = MenuBarImageBuilder.image(for: spec)
        button.attributedTitle = NSAttributedString(string: "")
    }
```
In `togglePopover()` (open branch), after the quota `refreshIfStale`, add: `activityStore.refreshIfStale()`.

- [ ] **Step 4: Run all tests + live anchor check**

Run: `swift test && swift build`
Expected: PASS.

Live check: `swift run AILimitBar` in background, wait 5 s, confirm alive (`pgrep -x AILimitBar || pgrep -f AILimitBar`), then kill. The visual anchor/gap verification is a human step (Task 11 checklist) — process-alive is the pass bar here.

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/App/StatusItemController.swift Tests/AILimitBarKitTests/StatusItemLogicTests.swift
git commit -m "feat: composite status item rendering and activity refresh wiring"
```

---

### Task 11: Docs, bundle, verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README**

- Settings paragraph: remove "three animated pixel avatars (BOO / BUG / BOT)"; describe provider tabs (Claude live, Gemini coming soon) and the ACTIVITY 24H section: "reads aggregate counts (skill/agent names only) from your local Claude Code transcripts; nothing leaves your machine."
- Add to Security section: "The activity section scans `~/.claude/projects` locally and keeps only name+count aggregates in memory."
- Add a Behavior note: "The menu bar animation pauses while macOS Low Power Mode is on."

- [ ] **Step 2: Full verification**

Run: `swift test && ./Scripts/bundle.sh`
Expected: all tests pass; `Built AILimitBar.app (ad-hoc signed)`.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: README updates for tabs, activity section, low power note"
```

- [ ] **Step 4: Human smoke checklist (delta) — report to user, do not self-check**

- [ ] Menu bar: avatar + % (7 pt) + mini bar in one compact block; animation visibly flips (Low Power OFF)
- [ ] Popover opens flush under the menu bar (standard offset)
- [ ] Tabs CLAUDE/GEMINI switch and persist across reopen
- [ ] Gemini tab: INSERT CARTRIDGE + hint (EN/TH per language)
- [ ] ACTIVITY 24H shows real skill/agent counts; SCANNING… on first open
- [ ] UPDATED footer ticks (JUST NOW → 1M AGO)
- [ ] Both themes readable with softened colors
- [ ] SETTINGS + QUIT buttons work; settings no longer shows avatar pane

---

## Self-Review Notes

- Spec coverage: §2 menu bar (T3, T10), §3 popover structure/tabs/footer (T9), §4 palettes (T1), §5 scanner+store (T7, T8), §6 sprites (T4), §7 settings (T5), §8 L10n (T6), §9 tests distributed per task + smoke delta (T11).
- Compile-green sequencing: T3's test temporarily uses the V1 `sprite(for: .boo)` API (noted inline); T4 flips it and updates all call sites in the same commit; T9 wires ActivityStore into the controller so the package never breaks between tasks.
- `offlineBadge` now reuses `RelativeTimeFormatter` (replacing V1's `formatted(date:time:)`) — intentional small consolidation, same information.
