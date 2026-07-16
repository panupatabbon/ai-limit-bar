# Multi-Provider Support (v0.4.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user enable any subset of {Claude, Codex, Gemini, Cursor}; the menu bar shows one avatar block per enabled live provider, the popover shows sprite-face tabs per enabled provider; real data ships for Claude now and for Codex/Gemini behind research gates.

**Architecture:** N × `QuotaStore` (one per enabled live provider, reused untouched) coordinated by a new `ProviderHub`; a static `ProviderCatalog` is the single flip point from `.comingSoon` to `.live` per adapter. Spec: `docs/superpowers/specs/2026-07-17-multi-provider-design.md` — its Decisions section is settled; do not re-litigate.

**Tech Stack:** Swift 5.9+, SwiftPM, SwiftUI + AppKit (macOS 14+), XCTest.

## Global Constraints

- Branch: `feat/multi-provider` (already created off main v0.3.0). Never commit to main.
- Read-only security posture: adapters read local credentials only, token stays in memory, exactly one HTTPS endpoint per provider, no telemetry.
- Pixel doctrine (DESIGN.md): no shadows/gradients/rounding; colors only via `RetroTheme`; Press Start 2P only via `pixelType(size:)`; sprites 16×16 with 4-frame loop `[base, alt, base, blink]`.
- Fixed provider order everywhere: claude → codex → gemini → cursor.
- Min-1 rule: at least one **live** provider always enabled (data layer + UI).
- Every commit message ends with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- Run `swift test` from the repo root; all existing 78 tests must stay green in every task.

---

### Task 1: `ProviderID` + `ProviderCatalog` (replaces `ProviderTab`)

**Files:**
- Create: `Sources/AILimitBarKit/Core/ProviderCatalog.swift`
- Modify: `Sources/AILimitBarKit/Core/AppSettings.swift` (delete `ProviderTab` enum at top; retype `selectedTab`)
- Modify: `Sources/AILimitBarKit/UI/Popover/QuotaPopoverView.swift` (rename type refs; make the tab switch exhaustive via `default`)
- Test: `Tests/AILimitBarKitTests/ProviderCatalogTests.swift`

**Interfaces:**
- Consumes: `QuotaProvider`, `ClaudeProvider` (existing).
- Produces: `ProviderID: String, CaseIterable, Sendable` (cases `claude, codex, gemini, cursor`); `ProviderAvailability { case live, comingSoon }`; `ProviderDescriptor { id, displayName, cliName, availability }`; `ProviderCatalog.all: [ProviderDescriptor]`, `ProviderCatalog.descriptor(for:) -> ProviderDescriptor`, `ProviderCatalog.liveIDs: Set<ProviderID>`, `ProviderCatalog.makeProvider(for:) -> QuotaProvider?`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AILimitBarKit

final class ProviderCatalogTests: XCTestCase {
    func testFixedOrderAndCompleteness() {
        XCTAssertEqual(ProviderID.allCases, [.claude, .codex, .gemini, .cursor])
        XCTAssertEqual(ProviderCatalog.all.map(\.id), ProviderID.allCases)
    }

    func testDisplayAndCLINames() {
        XCTAssertEqual(ProviderCatalog.descriptor(for: .claude).cliName, "Claude Code")
        XCTAssertEqual(ProviderCatalog.descriptor(for: .codex).cliName, "Codex CLI")
        XCTAssertEqual(ProviderCatalog.descriptor(for: .gemini).cliName, "Gemini CLI")
        XCTAssertEqual(ProviderCatalog.descriptor(for: .cursor).displayName, "Cursor")
    }

    func testAvailabilityMatchesFactory() {
        // The catalog's availability flag and the factory must never diverge.
        for descriptor in ProviderCatalog.all {
            let hasProvider = ProviderCatalog.makeProvider(for: descriptor.id) != nil
            XCTAssertEqual(descriptor.availability == .live, hasProvider,
                           "\(descriptor.id) availability out of sync with factory")
        }
    }

    func testOnlyClaudeIsLiveInitially() {
        XCTAssertEqual(ProviderCatalog.liveIDs, [.claude])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ProviderCatalogTests 2>&1 | tail -5`
Expected: compile FAILURE — `ProviderID` / `ProviderCatalog` not defined.

- [ ] **Step 3: Create `ProviderCatalog.swift`**

```swift
import Foundation

public enum ProviderID: String, CaseIterable, Sendable {
    case claude, codex, gemini, cursor
}

public enum ProviderAvailability: Equatable, Sendable {
    case live, comingSoon
}

public struct ProviderDescriptor: Sendable {
    public let id: ProviderID
    public let displayName: String
    public let cliName: String
    public let availability: ProviderAvailability
}

public enum ProviderCatalog {
    public static let all: [ProviderDescriptor] = [
        .init(id: .claude, displayName: "Claude", cliName: "Claude Code", availability: .live),
        .init(id: .codex, displayName: "Codex", cliName: "Codex CLI", availability: .comingSoon),
        .init(id: .gemini, displayName: "Gemini", cliName: "Gemini CLI", availability: .comingSoon),
        .init(id: .cursor, displayName: "Cursor", cliName: "Cursor", availability: .comingSoon),
    ]

    public static func descriptor(for id: ProviderID) -> ProviderDescriptor {
        all.first { $0.id == id }!
    }

    public static var liveIDs: Set<ProviderID> {
        Set(all.filter { $0.availability == .live }.map(\.id))
    }

    /// The single flip point per adapter: when a provider goes live, return
    /// its QuotaProvider here AND set availability to .live above.
    public static func makeProvider(for id: ProviderID) -> QuotaProvider? {
        switch id {
        case .claude: return ClaudeProvider()
        case .codex, .gemini, .cursor: return nil
        }
    }
}
```

- [ ] **Step 4: Replace `ProviderTab` with `ProviderID`**

In `AppSettings.swift`: delete the line `public enum ProviderTab: String, CaseIterable, Sendable { case claude, gemini }` and retype the property:

```swift
    /// Deliberately not persisted while non-live tabs exist: every open
    /// must land on a live provider so the primary glance never dead-ends.
    public var selectedTab: ProviderID = .claude
```

In `QuotaPopoverView.swift`: replace every `ProviderTab` with `ProviderID`, and make the content switch exhaustive for the interim (Task 7 replaces it):

```swift
            switch settings.selectedTab {
            case .claude: claudeTab(palette)
            default: geminiTab(palette)
            }
```

(The temporary text tab bar will show four tabs until Task 7 replaces it with sprite tabs — acceptable interim state; no test asserts tab count.)

- [ ] **Step 5: Run full suite**

Run: `swift test 2>&1 | grep -E "Executed .* tests" | tail -1`
Expected: PASS — 78 existing + 4 new.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: ProviderID + ProviderCatalog, replace ProviderTab

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: `AppSettings.enabledProviders` with sanitize

**Files:**
- Modify: `Sources/AILimitBarKit/Core/AppSettings.swift`
- Test: `Tests/AILimitBarKitTests/AppSettingsTests.swift`

**Interfaces:**
- Consumes: `ProviderID`, `ProviderCatalog.liveIDs` (Task 1).
- Produces: `AppSettings.enabledProviders: Set<ProviderID>` (persisted, default `[.claude]`); `static AppSettings.sanitizedProviders(_ raw: [String]?) -> Set<ProviderID>`.

- [ ] **Step 1: Write the failing tests** (append to `AppSettingsTests`)

```swift
    func testEnabledProvidersDefaultAndPersistence() {
        let s1 = AppSettings(defaults: defaults)
        XCTAssertEqual(s1.enabledProviders, [.claude])
        s1.enabledProviders = [.claude, .codex]
        XCTAssertEqual(AppSettings(defaults: defaults).enabledProviders, [.claude, .codex])
    }

    func testSanitizedProviders() {
        // Unknown values dropped; a set with no live provider gets .claude back.
        XCTAssertEqual(AppSettings.sanitizedProviders(nil), [.claude])
        XCTAssertEqual(AppSettings.sanitizedProviders([]), [.claude])
        XCTAssertEqual(AppSettings.sanitizedProviders(["garbage", "claude"]), [.claude])
        XCTAssertEqual(AppSettings.sanitizedProviders(["cursor"]), [.cursor, .claude])
        XCTAssertEqual(AppSettings.sanitizedProviders(["claude", "gemini"]), [.claude, .gemini])
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter AppSettingsTests 2>&1 | tail -3`
Expected: compile FAILURE — `enabledProviders` not defined.

- [ ] **Step 3: Implement in `AppSettings`**

Add the property alongside the others and the loader in `init`:

```swift
    public var enabledProviders: Set<ProviderID> {
        didSet { defaults.set(enabledProviders.map(\.rawValue).sorted(), forKey: "enabledProviders") }
    }
```

```swift
        enabledProviders = Self.sanitizedProviders(defaults.stringArray(forKey: "enabledProviders"))
```

And the pure sanitizer:

```swift
    /// Unknown values dropped; if no *live* provider remains (empty set, or
    /// only coming-soon providers — possible when catalog availability
    /// changes across versions), .claude is added back so the menu bar can
    /// never be empty.
    public static func sanitizedProviders(_ raw: [String]?) -> Set<ProviderID> {
        var set = Set((raw ?? [ProviderID.claude.rawValue]).compactMap(ProviderID.init(rawValue:)))
        if set.isDisjoint(with: ProviderCatalog.liveIDs) { set.insert(.claude) }
        return set
    }
```

- [ ] **Step 4: Run full suite** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: persisted enabledProviders with min-1-live sanitize

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `ProviderHub`

**Files:**
- Create: `Sources/AILimitBarKit/Core/ProviderHub.swift`
- Test: `Tests/AILimitBarKitTests/ProviderHubTests.swift`

**Interfaces:**
- Consumes: `QuotaStore` (existing, untouched), `ProviderCatalog.makeProvider(for:)`, `HeadlinePin`, `Severity`.
- Produces: `ProviderHub` (`@MainActor @Observable`): `init(storeFactory:)`, `sync(enabled: Set<ProviderID>)`, `orderedEnabled: [ProviderID]`, `orderedLive: [ProviderID]`, `store(for:) -> QuotaStore?`, `hottest(pin:) -> ProviderID?`.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import AILimitBarKit

private struct FakeProvider: QuotaProvider {
    let id = "fake"
    let displayName = "Fake"
    let percent: Double
    func fetchSnapshot() async throws -> QuotaSnapshot {
        QuotaSnapshot(planName: "FAKE",
                      limits: [QuotaLimit(kind: .session, percentUsed: percent,
                                          resetsAt: Date().addingTimeInterval(3600), isActive: true)],
                      fetchedAt: Date())
    }
}

@MainActor
final class ProviderHubTests: XCTestCase {
    private func makeHub(percents: [ProviderID: Double]) -> ProviderHub {
        ProviderHub { id in
            guard let percent = percents[id] else { return nil }
            return QuotaStore(provider: FakeProvider(percent: percent))
        }
    }

    func testSyncCreatesAndRemovesStores() {
        let hub = makeHub(percents: [.claude: 10, .codex: 20])
        hub.sync(enabled: [.claude, .codex, .cursor])
        // .cursor has no factory result (coming soon) — no store.
        XCTAssertEqual(hub.orderedLive, [.claude, .codex])
        XCTAssertEqual(hub.orderedEnabled, [.claude, .codex, .cursor])
        XCTAssertNotNil(hub.store(for: .claude))
        XCTAssertNil(hub.store(for: .cursor))

        hub.sync(enabled: [.claude])
        XCTAssertEqual(hub.orderedLive, [.claude])
        XCTAssertNil(hub.store(for: .codex))
    }

    func testOrderedFollowsFixedOrder() {
        let hub = makeHub(percents: [.claude: 10, .gemini: 10])
        hub.sync(enabled: [.gemini, .claude])
        XCTAssertEqual(hub.orderedEnabled, [.claude, .gemini])
    }

    func testHottestPicksHighestSeverityThenOrder() async {
        let hub = makeHub(percents: [.claude: 70, .codex: 90, .gemini: 65])
        hub.sync(enabled: [.claude, .codex, .gemini])
        for id in hub.orderedLive { await hub.store(for: id)!.refresh() }
        XCTAssertEqual(hub.hottest(pin: .auto), .codex)          // critical beats warn
    }

    func testHottestTieBreaksByOrderAndNilWhenAllOK() async {
        let warmTie = makeHub(percents: [.claude: 70, .codex: 72])
        warmTie.sync(enabled: [.claude, .codex])
        for id in warmTie.orderedLive { await warmTie.store(for: id)!.refresh() }
        XCTAssertEqual(warmTie.hottest(pin: .auto), .claude)     // both warn → first

        let calm = makeHub(percents: [.claude: 10, .codex: 20])
        calm.sync(enabled: [.claude, .codex])
        for id in calm.orderedLive { await calm.store(for: id)!.refresh() }
        XCTAssertNil(calm.hottest(pin: .auto))                   // nobody ≥ warn
    }
}
```

- [ ] **Step 2: Run to verify failure** — compile FAILURE, `ProviderHub` not defined.

- [ ] **Step 3: Implement `ProviderHub.swift`**

```swift
import Foundation
import Observation

/// Owns one QuotaStore per enabled *live* provider. Disable = stop polling
/// and drop the store, not hide. Coming-soon providers never get a store.
@MainActor
@Observable
public final class ProviderHub {
    public private(set) var stores: [ProviderID: QuotaStore] = [:]
    private var enabled: Set<ProviderID> = []
    private let storeFactory: (ProviderID) -> QuotaStore?

    public init(storeFactory: @escaping (ProviderID) -> QuotaStore? = ProviderHub.liveStore(for:)) {
        self.storeFactory = storeFactory
    }

    public static func liveStore(for id: ProviderID) -> QuotaStore? {
        guard let provider = ProviderCatalog.makeProvider(for: id) else { return nil }
        let store = QuotaStore(provider: provider)
        store.startPolling(interval: 60)
        return store
    }

    public func sync(enabled: Set<ProviderID>) {
        guard enabled != self.enabled else { return }
        self.enabled = enabled
        for id in ProviderID.allCases {
            if enabled.contains(id), stores[id] == nil, let store = storeFactory(id) {
                stores[id] = store
            } else if !enabled.contains(id), let store = stores[id] {
                store.stopPolling()
                stores[id] = nil
            }
        }
    }

    public var orderedEnabled: [ProviderID] {
        ProviderID.allCases.filter { enabled.contains($0) }
    }

    public var orderedLive: [ProviderID] {
        ProviderID.allCases.filter { stores[$0] != nil }
    }

    public func store(for id: ProviderID) -> QuotaStore? { stores[id] }

    /// The provider that most needs attention: highest severity ≥ warn,
    /// ties broken by fixed order. Nil when everyone is ok.
    public func hottest(pin: HeadlinePin) -> ProviderID? {
        var best: (id: ProviderID, rank: Int)?
        for id in orderedLive {
            guard let headline = stores[id]?.headlineLimit(pin: pin) else { continue }
            let rank: Int
            switch Severity(percent: headline.percentUsed) {
            case .ok: continue
            case .warn: rank = 1
            case .critical: rank = 2
            }
            if rank > (best?.rank ?? 0) { best = (id, rank) }
        }
        return best?.id
    }
}
```

- [ ] **Step 4: Run full suite** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: ProviderHub — per-provider store lifecycle and hottest()

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Codex + Cursor sprites

**Files:**
- Modify: `Sources/AILimitBarKit/UI/Retro/SpriteLibrary.swift`
- Test: `Tests/AILimitBarKitTests/SpriteTests.swift`

**Interfaces:**
- Produces: `SpriteLibrary.sprite(forProvider:)` resolves `"codex"` and `"cursor"`; sprites keep the `Sprite(id:base:alt:blink:)` shape.

- [ ] **Step 1: Update tests** — change the providers list and add the cursor-blink case:

```swift
    private let providers = ["claude", "codex", "gemini", "cursor"]
```

```swift
    func testCursorBlinkFrameIsEmpty() {
        // The I-beam's blink IS a text-cursor blink: the frame goes dark.
        let cursor = SpriteLibrary.sprite(forProvider: "cursor")
        XCTAssertFalse(cursor.frames[3].bitmap.flatMap { $0 }.contains(true))
        // base frame still has real mass
        XCTAssertGreaterThanOrEqual(cursor.frames[0].bitmap.flatMap { $0 }.filter { $0 }.count, 30)
    }
```

- [ ] **Step 2: Run to verify failure** — `sprite(forProvider: "codex")` falls back to claude → `testProviderSpritesAre16x16With4Frames` fails on `sprite.id`.

- [ ] **Step 3: Add sprites to `SpriteLibrary`**

Extend the switch:

```swift
    public static func sprite(forProvider id: String) -> Sprite {
        switch id {
        case "gemini": return gemini
        case "codex": return codex
        case "cursor": return cursor
        default: return claude
        }
    }
```

Add the art (rows are the contract; pixel-level tuning during implementation is fine as long as every test — 16×16, 4 frames, base/alt diff ≥ 8px, cursor blink empty — passes):

```swift
    // CODEX — hex-blossom: six petals around a hollow hexagonal core.
    // alt: diagonal petals rotate a step; blink: the core contracts.
    static let codex = Sprite(
        id: "codex",
        base: SpriteFrame(rows: [
            "................",
            "......####......",
            "......####......",
            "..##........##..",
            ".####......####.",
            ".####......####.",
            "..##..####..##..",
            ".....#....#.....",
            ".....#....#.....",
            "..##..####..##..",
            ".####......####.",
            ".####......####.",
            "..##........##..",
            "......####......",
            "......####......",
            "................",
        ]),
        alt: SpriteFrame(rows: [
            "................",
            ".......##.......",
            "......####......",
            ".###........###.",
            ".####......####.",
            "..###......###..",
            "..##..####..##..",
            ".....#....#.....",
            ".....#....#.....",
            "..##..####..##..",
            "..###......###..",
            ".####......####.",
            ".###........###.",
            "......####......",
            ".......##.......",
            "................",
        ]),
        blink: SpriteFrame(rows: [
            "................",
            "......####......",
            "......####......",
            "..##........##..",
            ".####......####.",
            ".####......####.",
            "..##........##..",
            "......####......",
            "......####......",
            "..##........##..",
            ".####......####.",
            ".####......####.",
            "..##........##..",
            "......####......",
            "......####......",
            "................",
        ]))

    // CURSOR — I-beam with heavy serifs for mass. alt: 1px vertical shift;
    // blink: empty frame (a literal text-cursor blink).
    static let cursor = Sprite(
        id: "cursor",
        base: SpriteFrame(rows: [
            "................",
            "..###......###..",
            "..############..",
            "..###......###..",
            ".......##.......",
            ".......##.......",
            ".......##.......",
            ".......##.......",
            ".......##.......",
            ".......##.......",
            ".......##.......",
            ".......##.......",
            "..###......###..",
            "..############..",
            "..###......###..",
            "................",
        ]),
        alt: SpriteFrame(rows: [
            "................",
            "................",
            "..###......###..",
            "..############..",
            "..###......###..",
            ".......##.......",
            ".......##.......",
            ".......##.......",
            ".......##.......",
            ".......##.......",
            ".......##.......",
            ".......##.......",
            "..###......###..",
            "..############..",
            "..###......###..",
            "................",
        ]),
        blink: SpriteFrame(rows: [
            "................", "................", "................", "................",
            "................", "................", "................", "................",
            "................", "................", "................", "................",
            "................", "................", "................", "................",
        ]))
```

- [ ] **Step 4: Run full suite** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: codex hex-blossom and cursor I-beam sprites

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: `MenuBarImageBuilder` multi-spec composition

**Files:**
- Modify: `Sources/AILimitBarKit/UI/Retro/MenuBarImageBuilder.swift`
- Test: `Tests/AILimitBarKitTests/MenuBarImageBuilderTests.swift`

**Interfaces:**
- Consumes: existing `Spec`.
- Produces: `MenuBarImageBuilder.providerGap: CGFloat == 8`; `layoutWidth(for specs: [Spec]) -> CGFloat`; `image(for specs: [Spec]) -> NSImage`. Existing single-spec `layoutWidth(for:)`/`image(for:)` unchanged.

- [ ] **Step 1: Write the failing tests** (append)

```swift
    func testMultiSpecWidthAddsGapBetweenBlocks() {
        let a = spec(text: nil, bar: nil)      // 16
        let b = spec(text: nil, bar: 0.5)      // 33
        XCTAssertEqual(MenuBarImageBuilder.layoutWidth(for: [a, b]),
                       16 + MenuBarImageBuilder.providerGap + 33)
        XCTAssertEqual(MenuBarImageBuilder.layoutWidth(for: [a]), 16)
        XCTAssertEqual(MenuBarImageBuilder.layoutWidth(for: []), 0)
    }

    func testMultiSpecImageMatchesLayout() {
        let specs = [spec(text: "42%", bar: 0.42), spec(text: nil, bar: nil)]
        let image = MenuBarImageBuilder.image(for: specs)
        XCTAssertEqual(image.size.height, 18)
        XCTAssertEqual(image.size.width, MenuBarImageBuilder.layoutWidth(for: specs))
    }
```

- [ ] **Step 2: Run to verify failure** — compile FAILURE: no `[Spec]` overloads.

- [ ] **Step 3: Implement**

Refactor the drawing body of `image(for spec:)` into a private `draw(_ spec: Spec, atX: CGFloat)` (same code, `x` offsets added to `0`, `rightX`), then:

```swift
    static let providerGap: CGFloat = 8

    public static func layoutWidth(for specs: [Spec]) -> CGFloat {
        guard !specs.isEmpty else { return 0 }
        return specs.map { layoutWidth(for: $0) }.reduce(0, +)
            + CGFloat(specs.count - 1) * providerGap
    }

    public static func image(for specs: [Spec]) -> NSImage {
        let image = NSImage(size: NSSize(width: layoutWidth(for: specs), height: height))
        image.lockFocus()
        var x: CGFloat = 0
        for spec in specs {
            draw(spec, atX: x)
            x += layoutWidth(for: spec) + providerGap
        }
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
```

Keep `public static func image(for spec: Spec) -> NSImage { image(for: [spec]) }`.

- [ ] **Step 4: Run full suite** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: MenuBarImageBuilder composes multiple provider blocks

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: `StatusItemController` renders the hub

**Files:**
- Modify: `Sources/AILimitBarKit/App/StatusItemController.swift`
- Modify: `Sources/AILimitBarKit/App/AppDelegate.swift`
- Test: `Tests/AILimitBarKitTests/StatusItemLogicTests.swift`

**Interfaces:**
- Consumes: `ProviderHub` (Task 3), multi-spec builder (Task 5).
- Produces: `init(hub:settings:activity:)`; `static openTab(hottest: ProviderID?, enabled: [ProviderID]) -> ProviderID`; `static prefixedStatusDescription(name:multi:base:) -> String`. Existing statics (`menuBarSpec`, `menuBarTitle`, `statusDescription`) unchanged.

- [ ] **Step 1: Write the failing tests** (append)

```swift
    func testOpenTabRule() {
        XCTAssertEqual(StatusItemController.openTab(hottest: .codex, enabled: [.claude, .codex]), .codex)
        XCTAssertEqual(StatusItemController.openTab(hottest: nil, enabled: [.claude, .codex]), .claude)
        XCTAssertEqual(StatusItemController.openTab(hottest: nil, enabled: []), .claude)
    }

    func testPrefixedStatusDescription() {
        XCTAssertEqual(
            StatusItemController.prefixedStatusDescription(name: "Codex", multi: true, base: "Session 58% used"),
            "Codex: Session 58% used")
        XCTAssertEqual(
            StatusItemController.prefixedStatusDescription(name: "Claude", multi: false, base: "Session 58% used"),
            "Session 58% used")
    }
```

- [ ] **Step 2: Run to verify failure** — compile FAILURE.

- [ ] **Step 3: Implement**

Add statics:

```swift
    public static func openTab(hottest: ProviderID?, enabled: [ProviderID]) -> ProviderID {
        hottest ?? enabled.first ?? .claude
    }

    public static func prefixedStatusDescription(name: String, multi: Bool, base: String) -> String {
        multi ? "\(name): \(base)" : base
    }
```

Replace the stored `store` with `hub` (init/params rename; keep `settings`, `activityStore`). Replace the spec-gate property:

```swift
    private var lastSpecs: [MenuBarImageBuilder.Spec]?
```

In `tick()` add `hub.sync(enabled: settings.enabledProviders)` before `render()`. Rewrite `render()`'s data assembly:

```swift
    private func render() {
        guard let button = statusItem?.button else { return }
        let darkAppearance = button.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let describedID = Self.openTab(hottest: hub.hottest(pin: settings.headlinePin),
                                       enabled: hub.orderedLive)
        if let store = hub.store(for: describedID) {
            let base = Self.statusDescription(
                headline: store.headlineLimit(pin: settings.headlinePin), state: store.state)
            let description = Self.prefixedStatusDescription(
                name: ProviderCatalog.descriptor(for: describedID).displayName,
                multi: hub.orderedEnabled.count > 1, base: base)
            button.toolTip = description
            button.setAccessibilityLabel(description)
        }

        let specs: [MenuBarImageBuilder.Spec] = hub.orderedLive.compactMap { id in
            guard let store = hub.store(for: id) else { return nil }
            let headline = store.headlineLimit(pin: settings.headlinePin)
            let sprite = SpriteLibrary.sprite(forProvider: id.rawValue)
            let mood: SpriteMood
            switch store.state {
            case .ready, .offline:
                mood = SpriteMood(severity: headline.map { Severity(percent: $0.percentUsed) })
            default:
                mood = .calm
            }
            return Self.menuBarSpec(headline: headline, state: store.state,
                                    showPercent: settings.showPercentInMenuBar,
                                    frame: sprite.frame(mood: mood, tick: frameIndex),
                                    darkAppearance: darkAppearance)
        }
        guard specs != lastSpecs else { return }
        lastSpecs = specs
        button.image = MenuBarImageBuilder.image(for: specs)
        button.attributedTitle = NSAttributedString(string: "")
    }
```

In `handleClick()` replace the tab reset and refresh:

```swift
            settings.selectedTab = Self.openTab(hottest: hub.hottest(pin: settings.headlinePin),
                                                enabled: hub.orderedEnabled)
            for id in hub.orderedLive {
                if let store = hub.store(for: id) {
                    Task { await store.refreshIfStale(olderThan: 10) }
                }
            }
```

In `AppDelegate`:

```swift
        let settings = AppSettings()
        let hub = ProviderHub()
        hub.sync(enabled: settings.enabledProviders)
        let activity = ActivityStore()
        let controller = StatusItemController(hub: hub, settings: settings, activity: activity)
        self.hub = hub
        self.controller = controller
        controller.start()
```

(Drop `store`/`startPolling` — the hub polls per store. Keep a `private var hub: ProviderHub?` property. `QuotaPopoverView` construction inside the controller changes signature in Task 7; for this task pass `store: hub.store(for: .claude)!` temporarily is NOT acceptable — instead do Tasks 6 and 7 back-to-back if the popover init blocks compilation; the popover still takes a single `store` until Task 7, so pass `hub.store(for: .claude) ?? QuotaStore(provider: ClaudeProvider())` as interim with a `// Task 7 removes this` comment.)

- [ ] **Step 4: Run full suite** — Expected: PASS (updated tests included).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: status item renders all live providers via ProviderHub

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Popover — sprite-face tabs + per-provider content

**Files:**
- Create: `Sources/AILimitBarKit/UI/Retro/SpriteIconView.swift`
- Modify: `Sources/AILimitBarKit/UI/Popover/QuotaPopoverView.swift`
- Modify: `Sources/AILimitBarKit/App/StatusItemController.swift` (popover construction)
- Test: `Tests/AILimitBarKitTests/PopoverLogicTests.swift`

**Interfaces:**
- Consumes: `ProviderHub`, `ProviderCatalog`, sprites (Tasks 1–4).
- Produces: `QuotaPopoverView(hub:settings:activity:onOpenSettings:onQuit:)`; `static resolvedTab(selected:enabled:) -> ProviderID`; `static showsTabBar(enabledCount:) -> Bool`; `static credentialsHint(cliName:) -> String`; `static tokenExpiredHint(cliName:) -> String`; `static comingSoonHint(displayName:) -> String`.

- [ ] **Step 1: Write the failing tests** (append)

```swift
    func testResolvedTabFallsBackToFirstEnabled() {
        XCTAssertEqual(QuotaPopoverView.resolvedTab(selected: .codex, enabled: [.claude, .codex]), .codex)
        XCTAssertEqual(QuotaPopoverView.resolvedTab(selected: .codex, enabled: [.claude, .gemini]), .claude)
        XCTAssertEqual(QuotaPopoverView.resolvedTab(selected: .codex, enabled: []), .claude)
    }

    func testTabBarHiddenForSingleProvider() {
        XCTAssertFalse(QuotaPopoverView.showsTabBar(enabledCount: 1))
        XCTAssertTrue(QuotaPopoverView.showsTabBar(enabledCount: 2))
    }

    func testPerProviderStateCopy() {
        XCTAssertEqual(QuotaPopoverView.credentialsHint(cliName: "Codex CLI"),
                       "Install and sign in to Codex CLI first — this app reads its quota data.")
        XCTAssertEqual(QuotaPopoverView.tokenExpiredHint(cliName: "Gemini CLI"),
                       "Use Gemini CLI once to renew the token, then this app recovers automatically.")
        XCTAssertEqual(QuotaPopoverView.comingSoonHint(displayName: "Cursor"),
                       "Cursor support is coming soon.")
    }
```

- [ ] **Step 2: Run to verify failure** — compile FAILURE.

- [ ] **Step 3: Create `SpriteIconView.swift`** (static face for tabs; no animation — tabs are chrome, not status)

```swift
import SwiftUI

/// A sprite's resting face at 1px scale — used for tab chrome.
public struct SpriteIconView: View {
    let sprite: Sprite
    let color: Color

    public init(sprite: Sprite, color: Color) {
        self.sprite = sprite
        self.color = color
    }

    public var body: some View {
        Canvas { ctx, _ in
            for (y, row) in sprite.frames[0].bitmap.enumerated() {
                for (x, filled) in row.enumerated() where filled {
                    ctx.fill(Path(CGRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1)),
                             with: .color(color))
                }
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 4: Rework `QuotaPopoverView`**

Statics:

```swift
    public static func resolvedTab(selected: ProviderID, enabled: [ProviderID]) -> ProviderID {
        enabled.contains(selected) ? selected : (enabled.first ?? .claude)
    }

    public static func showsTabBar(enabledCount: Int) -> Bool { enabledCount > 1 }

    public static func credentialsHint(cliName: String) -> String {
        "Install and sign in to \(cliName) first — this app reads its quota data."
    }

    public static func tokenExpiredHint(cliName: String) -> String {
        "Use \(cliName) once to renew the token, then this app recovers automatically."
    }

    public static func comingSoonHint(displayName: String) -> String {
        "\(displayName) support is coming soon."
    }
```

Stored properties: replace `let store: QuotaStore` with `let hub: ProviderHub`. Body:

```swift
        let enabled = hub.orderedEnabled
        let tab = Self.resolvedTab(selected: settings.selectedTab, enabled: enabled)
        VStack(alignment: .leading, spacing: 16) {
            if Self.showsTabBar(enabledCount: enabled.count) {
                tabBar(enabled: enabled, active: tab, palette)
            }
            providerContent(for: tab, palette)
            footer(palette)
        }
```

Sprite-face tab bar (replaces the text tabs; keeps VO labels, traits, focus ring):

```swift
    @ViewBuilder
    private func tabBar(enabled: [ProviderID], active: ProviderID, _ palette: RetroPalette) -> some View {
        HStack(spacing: 6) {
            ForEach(enabled, id: \.self) { id in
                Button {
                    settings.selectedTab = id
                } label: {
                    SpriteIconView(sprite: SpriteLibrary.sprite(forProvider: id.rawValue),
                                   color: active == id ? palette.background
                                                       : palette.textPrimary.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(active == id ? palette.accentCyan : palette.surface)
                }
                .buttonStyle(.plain)
                .help(ProviderCatalog.descriptor(for: id).displayName)
                .accessibilityLabel("\(ProviderCatalog.descriptor(for: id).displayName) tab")
                .accessibilityAddTraits(active == id ? [.isSelected] : [])
                .pixelFocusRing()
            }
            Spacer()
        }
    }
```

Per-provider content (replaces `claudeTab`/`geminiTab` and the old switch; `header`, `sectionHeader`, `limitList`, `stateScreen`, `offlineBadge`, `activitySection` keep their bodies but take the tab's `store` where they used `self.store`, and `quotaContent` uses the hint statics with the descriptor's `cliName`):

```swift
    @ViewBuilder
    private func providerContent(for id: ProviderID, _ palette: RetroPalette) -> some View {
        let descriptor = ProviderCatalog.descriptor(for: id)
        if let store = hub.store(for: id) {
            header(store: store, providerID: id, palette)
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("QUOTA", palette)
                quotaContent(store: store, cliName: descriptor.cliName, palette)
            }
            if id == .claude {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("ACTIVITY 24H", palette)
                    activitySection(palette)
                }
            }
        } else {
            comingSoon(descriptor, palette)
        }
    }

    @ViewBuilder
    private func comingSoon(_ descriptor: ProviderDescriptor, _ palette: RetroPalette) -> some View {
        VStack(spacing: 12) {
            AvatarSpriteView(sprite: SpriteLibrary.sprite(forProvider: descriptor.id.rawValue),
                             color: palette.accentCyan, pixelScale: 3)
            Text("INSERT CARTRIDGE")
                .pixelType(size: 12)
                .foregroundStyle(palette.accentPink)
            Text(Self.comingSoonHint(displayName: descriptor.displayName))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(palette.textPrimary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
```

In `quotaContent`, the two hint strings become `Self.credentialsHint(cliName: cliName)` / `Self.tokenExpiredHint(cliName: cliName)`; `visibleLimits`, `noDataHint`, `limitList`, RETRY button all read the passed `store`. `headlineSeverity`/`headlineColor` become functions of the passed store. Delete `geminiTab`.

In `StatusItemController.start()` construct with the hub:

```swift
            rootView: QuotaPopoverView(hub: hub, settings: settings,
                                       activity: activityStore) { ... } onQuit: { ... }
```

Remove the Task 6 interim comment/workaround.

- [ ] **Step 5: Run full suite** — Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: sprite-face tabs and per-provider popover content

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Settings PROVIDERS section

**Files:**
- Modify: `Sources/AILimitBarKit/UI/Settings/SettingsView.swift`
- Test: `Tests/AILimitBarKitTests/AppSettingsTests.swift` (SettingsView logic test lives here beside settings tests)

**Interfaces:**
- Produces: `static SettingsView.canToggle(_ id:, enabled:) -> Bool`.

- [ ] **Step 1: Write the failing test**

```swift
    @MainActor
    func testCanToggleEnforcesMinOneLive() {
        // Enabling anything is always allowed.
        XCTAssertTrue(SettingsView.canToggle(.codex, enabled: [.claude]))
        // Disabling the only live provider is forbidden…
        XCTAssertFalse(SettingsView.canToggle(.claude, enabled: [.claude]))
        XCTAssertFalse(SettingsView.canToggle(.claude, enabled: [.claude, .cursor]))  // cursor isn't live
        // …but fine while another live provider remains (none besides claude is live yet,
        // so assert via the rule's shape: disabling a non-live provider is always allowed).
        XCTAssertTrue(SettingsView.canToggle(.cursor, enabled: [.claude, .cursor]))
    }
```

- [ ] **Step 2: Run to verify failure** — compile FAILURE.

- [ ] **Step 3: Implement**

Static rule + binding + section (insert the PROVIDERS section ABOVE the GENERAL section):

```swift
    /// Enabling is always allowed; disabling is allowed only if at least one
    /// live provider remains enabled afterwards.
    public static func canToggle(_ id: ProviderID, enabled: Set<ProviderID>) -> Bool {
        guard enabled.contains(id) else { return true }
        return !enabled.subtracting([id]).isDisjoint(with: ProviderCatalog.liveIDs)
    }

    private func providerBinding(_ id: ProviderID) -> Binding<Bool> {
        Binding(get: { settings.enabledProviders.contains(id) },
                set: { on in
                    if on { settings.enabledProviders.insert(id) }
                    else { settings.enabledProviders.remove(id) }
                })
    }
```

```swift
            section("PROVIDERS", palette) {
                ForEach(ProviderID.allCases, id: \.self) { id in
                    let descriptor = ProviderCatalog.descriptor(for: id)
                    Toggle(isOn: providerBinding(id)) {
                        HStack(spacing: 4) {
                            Text(descriptor.displayName)
                            if descriptor.availability == .comingSoon {
                                Text("(coming soon)")
                                    .foregroundStyle(palette.textPrimary.opacity(0.5))
                            }
                        }
                    }
                    .disabled(!Self.canToggle(id, enabled: settings.enabledProviders))
                }
            }
```

- [ ] **Step 4: Run full suite** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: PROVIDERS settings section with min-1-live rule

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: End-to-end verify + docs sync (framework complete)

**Files:**
- Modify: `README.md` (Provider Tabs + Settings sections), `DESIGN.md` (§Provider Tabs → sprite-face tabs; §Menu Bar Item multi-avatar; §Sprite Avatar new mascots; §Settings Form PROVIDERS)

- [ ] **Step 1: Full suite + build + run**

```bash
swift test 2>&1 | grep -E "Executed .* tests" | tail -1
./Scripts/bundle.sh && pkill -x AILimitBar; sleep 1; open ./AILimitBar.app
```

Manual checks: default install shows exactly the v0.3.0 experience (one Claude avatar, no tab bar); Settings → enable Codex/Gemini/Cursor → coming-soon tabs appear with hex-blossom / twin-stars / I-beam faces, menu bar unchanged (no live adapters yet); disable Claude toggle is blocked (only live provider).

- [ ] **Step 2: Update README.md**

Replace the Provider Tabs paragraph:

```markdown
### Provider Tabs

Pick which providers to track in Settings → PROVIDERS (Claude live today;
Codex, Gemini and Cursor appear as coming-soon tabs until their adapters
land). The menu bar shows one pixel avatar per live provider; the popover
opens on whichever provider most needs attention.
```

Add "PROVIDERS" to the Settings feature list line.

- [ ] **Step 3: Update DESIGN.md** — rewrite the affected component bullets to match the shipped behavior (sprite-face tabs spec from the design doc §UI surfaces; multi-avatar composition with 8pt provider gap; codex/cursor mascots including the empty cursor blink).

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "docs: README and DESIGN.md for multi-provider framework

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Codex research gate

**Files:**
- Create: `docs/superpowers/research/2026-07-17-codex-quota.md`

**Interfaces:**
- Produces: a research doc that Task 11 reads for exact constants. Pass criteria (ALL must hold): (1) documented credential file + JSON schema at `~/.codex/auth.json`, (2) a single HTTPS usage/rate-limit endpoint callable read-only with that token, (3) a captured real response body (secrets redacted) saved as the fixture, (4) a mapping table from response fields to `QuotaSnapshot` (session/weekly analogues, percent, reset time).

- [ ] **Step 1: Inspect local credentials**

```bash
ls -la ~/.codex/ && python3 -c "import json;d=json.load(open('$HOME/.codex/auth.json'));print({k:(type(v).__name__) for k,v in d.items()})"
```

Record the key structure (never the token values) in the research doc.

- [ ] **Step 2: Find the endpoint from the CLI's own source**

Codex CLI is open source. Search the repo for its usage/rate-limit call:

```bash
gh api "search/code?q=repo:openai/codex+rate_limit+in:file&per_page=10" -q '.items[].path'
gh api "search/code?q=repo:openai/codex+usage+endpoint+in:file&per_page=10" -q '.items[].path'
```

Then read the matching source files (raw.githubusercontent.com) to extract: base URL, path, auth header shape, response schema. Record verbatim in the doc.

- [ ] **Step 3: Verify read-only fetch with the local token**

Reproduce the CLI's request once with `curl` (Authorization header from auth.json), save the redacted response JSON into the research doc as the test fixture. If the request fails structurally (no such endpoint / auth model incompatible), record WHY.

- [ ] **Step 4: Verdict + commit**

Write `Verdict: PASS` (with the mapping table) or `Verdict: FAIL` (with reason) at the top of the doc.

```bash
git add docs/superpowers/research && git commit -m "research: Codex CLI quota channel findings

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

**If Verdict is FAIL: skip Task 11 entirely.** The catalog keeps Codex as `.comingSoon`; continue with Task 12.

---

### Task 11: `CodexProvider` (only if Task 10 passed)

**Files:**
- Create: `Sources/AILimitBarKit/Providers/Codex/CodexCredentials.swift`, `Sources/AILimitBarKit/Providers/Codex/CodexUsageClient.swift`, `Sources/AILimitBarKit/Providers/Codex/CodexProvider.swift`
- Modify: `Sources/AILimitBarKit/Core/ProviderCatalog.swift` (flip `.codex` to `.live` + factory)
- Test: `Tests/AILimitBarKitTests/CodexProviderTests.swift`

**Interfaces:**
- Consumes: the constants and fixture from `docs/superpowers/research/2026-07-17-codex-quota.md` — endpoint URL, auth header, response schema, field mapping. Those values are the source of truth; the code below shows the required structure.
- Produces: `CodexProvider: QuotaProvider` (`id == "codex"`).

- [ ] **Step 1: Write the failing decode test using the captured fixture**

Mirror `UsageResponseTests` style: paste the redacted fixture JSON from the research doc as a Swift string, decode, assert the mapped `QuotaSnapshot` (limit kinds, percentages, reset dates per the mapping table). Include a garbage-JSON `XCTAssertThrowsError` case.

- [ ] **Step 2: Run to verify failure** — compile FAILURE.

- [ ] **Step 3: Implement the three files following the Claude adapter's structure**

`CodexCredentials`: read + cache `~/.codex/auth.json`, expose the access token, throw `QuotaError.credentialsMissing` when absent — same shape as `ClaudeCredentials`. `CodexUsageClient`: one `URLSession` GET to the researched endpoint with the researched header; decode the researched schema; map to `QuotaSnapshot` exactly per the mapping table; expired token → `QuotaError.tokenExpired`. `CodexProvider`: glue struct mirroring `ClaudeProvider` (`id: "codex"`, `displayName: "Codex"`).

- [ ] **Step 4: Flip the catalog**

In `ProviderCatalog`: `.codex` descriptor `availability: .live`; `makeProvider` `case .codex: return CodexProvider()`. `ProviderCatalogTests.testOnlyClaudeIsLiveInitially` updates to `[.claude, .codex]` (rename it `testLiveProviders`).

- [ ] **Step 5: Full suite + live run**

`swift test`, then bundle + relaunch and confirm the Codex avatar appears with real percentages (or "!" if signed out).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: CodexProvider — live Codex CLI quota

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 12: Gemini research gate

Same structure and pass criteria as Task 10, targeting Gemini CLI.

**Files:**
- Create: `docs/superpowers/research/2026-07-17-gemini-quota.md`

- [ ] **Step 1:** Inspect `~/.gemini/` for credential/OAuth files (schema only, never values).
- [ ] **Step 2:** Search the open-source Gemini CLI (`google-gemini/gemini-cli`) for its quota/limit reporting path (`gh api search/code` as in Task 10) and read the relevant sources.
- [ ] **Step 3:** Reproduce one read-only fetch; capture a redacted fixture.
- [ ] **Step 4:** `Verdict: PASS`/`FAIL` + commit as in Task 10. **If FAIL: skip Task 13.**

---

### Task 13: `GeminiProvider` (only if Task 12 passed)

Mirror Task 11 exactly with `Sources/AILimitBarKit/Providers/Gemini/` (`GeminiCredentials`, `GeminiUsageClient`, `GeminiProvider`, fixture-driven `GeminiProviderTests`), then flip `.gemini` in `ProviderCatalog` (descriptor `.live`, factory returns `GeminiProvider()`) and update `testLiveProviders`. Full suite + bundle + relaunch + commit:

```bash
git add -A && git commit -m "feat: GeminiProvider — live Gemini CLI quota

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 14: Final verification pass

- [ ] **Step 1:** `swift test` — all green.
- [ ] **Step 2:** Bundle + relaunch. Walk every combination that changed: 1 provider (no tab bar), 2+ providers (sprite tabs, hottest-first open), signed-out live provider ("!" gold block + per-CLI INSERT COIN copy), coming-soon tab (INSERT CARTRIDGE, absent from menu bar), Settings min-1-live blocking, light + dark menu bar.
- [ ] **Step 3:** Update README/DESIGN.md for whichever adapters actually shipped (which providers are "live today").
- [ ] **Step 4:** Commit. Release mechanics (version bump to 0.4.0, merge to main, tag, GitHub Release) happen only when the user asks.

```bash
git add -A && git commit -m "docs: final multi-provider status sync

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
