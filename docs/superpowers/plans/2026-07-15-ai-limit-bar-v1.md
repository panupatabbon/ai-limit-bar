# ai-limit-bar V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS menu bar app showing Claude Pro/Max subscription quota (limit/used/reset) in an 8-bit arcade style, per the approved spec `docs/superpowers/specs/2026-07-15-ai-limit-bar-design.md`.

**Architecture:** Swift Package with a library target `AILimitBarKit` (all logic + UI, testable) and a thin executable `AILimitBar` (app boot). AppKit shell (`NSStatusItem` + `NSPopover`) hosts SwiftUI content. A single `@Observable` `QuotaStore` polls the verified endpoint every 60 s through a `QuotaProvider` protocol (Claude only in V1, Gemini later).

**Tech Stack:** Swift 6.3 toolchain (targets compiled in Swift 5 language mode to avoid strict-concurrency churn), SwiftUI + AppKit, XCTest, no third-party dependencies. Press Start 2P font (OFL) bundled.

## Global Constraints

- macOS deployment target: **14.0**; build with `swift build`, test with `swift test` (no `.xcodeproj`).
- **Read-only credentials**: never write Keychain or `~/.claude/.credentials.json`, never call any token-refresh endpoint.
- Only network destination: `https://api.anthropic.com/api/oauth/usage` with header `anthropic-beta: oauth-2025-04-20`.
- Access token lives in memory only; never logged. No telemetry.
- Severity thresholds: ok `< 60`, warn `60..<85`, critical `>= 85` (percent used).
- Game labels (SESSION, WEEKLY, RESET, INSERT COIN, SETTINGS…) stay English in both languages; only prose is localized EN/TH.
- Work on branch `feat/v1-design` (already exists, spec committed). Commit after every task.
- TDD: write the failing test first for every logic unit. UI-only rendering code is verified by build + the manual smoke checklist in Task 16.

---

### Task 1: SwiftPM scaffold

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/AILimitBarKit/Core/Placeholder.swift`
- Create: `Sources/AILimitBar/main.swift`
- Create: `Tests/AILimitBarKitTests/ScaffoldTests.swift`

**Interfaces:**
- Produces: package layout every later task builds on; library `AILimitBarKit`, executable `AILimitBar`, test target `AILimitBarKitTests`.

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ai-limit-bar",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "AILimitBarKit",
            path: "Sources/AILimitBarKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "AILimitBar",
            dependencies: ["AILimitBarKit"],
            path: "Sources/AILimitBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AILimitBarKitTests",
            dependencies: ["AILimitBarKit"],
            path: "Tests/AILimitBarKitTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
```

- [ ] **Step 2: Create .gitignore**

```
.build/
.swiftpm/
*.app
.DS_Store
```

- [ ] **Step 3: Create placeholder sources and test**

`Sources/AILimitBarKit/Core/Placeholder.swift`:
```swift
public enum AILimitBarKit {
    public static let version = "0.1.0"
}
```

`Sources/AILimitBar/main.swift`:
```swift
import AILimitBarKit
print("ai-limit-bar \(AILimitBarKit.version)")
```

`Tests/AILimitBarKitTests/ScaffoldTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

final class ScaffoldTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(AILimitBarKit.version, "0.1.0")
    }
}
```

- [ ] **Step 4: Verify build and test**

Run: `swift build && swift test`
Expected: `Build complete!` then `Test Suite 'All tests' passed` (1 test).

- [ ] **Step 5: Commit**

```bash
git add Package.swift .gitignore Sources Tests
git commit -m "chore: SwiftPM scaffold (Kit library + thin executable)"
```

---

### Task 2: Core models + Severity

**Files:**
- Create: `Sources/AILimitBarKit/Core/Models.swift`
- Test: `Tests/AILimitBarKitTests/SeverityTests.swift`

**Interfaces:**
- Produces:
  - `enum LimitKind: Equatable, Sendable { case session, weeklyAll, weeklyModel(String) }`
  - `struct QuotaLimit { let kind: LimitKind; let percentUsed: Double; let resetsAt: Date; let isActive: Bool }`
  - `struct QuotaSnapshot { let planName: String; let limits: [QuotaLimit]; let fetchedAt: Date }`
  - `enum Severity { case ok, warn, critical; init(percent: Double) }`
  - `protocol QuotaProvider { var id: String { get }; var displayName: String { get }; func fetchSnapshot() async throws -> QuotaSnapshot }`
  - `enum QuotaError: Error, Equatable { case credentialsMissing, tokenExpired, network(String), badResponse(String) }`

- [ ] **Step 1: Write the failing test**

`Tests/AILimitBarKitTests/SeverityTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

final class SeverityTests: XCTestCase {
    func testThresholds() {
        XCTAssertEqual(Severity(percent: 0), .ok)
        XCTAssertEqual(Severity(percent: 59.9), .ok)
        XCTAssertEqual(Severity(percent: 60), .warn)
        XCTAssertEqual(Severity(percent: 84.9), .warn)
        XCTAssertEqual(Severity(percent: 85), .critical)
        XCTAssertEqual(Severity(percent: 100), .critical)
        XCTAssertEqual(Severity(percent: 120), .critical) // extra usage overshoot
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SeverityTests`
Expected: FAIL — `cannot find 'Severity' in scope`.

- [ ] **Step 3: Write the models**

`Sources/AILimitBarKit/Core/Models.swift`:
```swift
import Foundation

public enum LimitKind: Equatable, Sendable {
    case session
    case weeklyAll
    case weeklyModel(String) // model display name, e.g. "Fable"
}

public struct QuotaLimit: Equatable, Sendable {
    public let kind: LimitKind
    public let percentUsed: Double // 0-100 (may exceed 100)
    public let resetsAt: Date
    public let isActive: Bool

    public init(kind: LimitKind, percentUsed: Double, resetsAt: Date, isActive: Bool) {
        self.kind = kind
        self.percentUsed = percentUsed
        self.resetsAt = resetsAt
        self.isActive = isActive
    }
}

public struct QuotaSnapshot: Equatable, Sendable {
    public let planName: String // "CLAUDE MAX"
    public let limits: [QuotaLimit]
    public let fetchedAt: Date

    public init(planName: String, limits: [QuotaLimit], fetchedAt: Date) {
        self.planName = planName
        self.limits = limits
        self.fetchedAt = fetchedAt
    }
}

public enum Severity: Equatable, Sendable {
    case ok, warn, critical

    public init(percent: Double) {
        switch percent {
        case ..<60: self = .ok
        case ..<85: self = .warn
        default: self = .critical
        }
    }
}

public protocol QuotaProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func fetchSnapshot() async throws -> QuotaSnapshot
}

public enum QuotaError: Error, Equatable {
    case credentialsMissing
    case tokenExpired
    case network(String)
    case badResponse(String)
}
```

Delete `Sources/AILimitBarKit/Core/Placeholder.swift` content is still needed by main.swift — leave it as is.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SeverityTests`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/Core/Models.swift Tests/AILimitBarKitTests/SeverityTests.swift
git commit -m "feat: core quota models and severity thresholds"
```

---

### Task 3: AnthropicDate parser

**Files:**
- Create: `Sources/AILimitBarKit/Core/AnthropicDate.swift`
- Test: `Tests/AILimitBarKitTests/AnthropicDateTests.swift`

**Interfaces:**
- Produces: `enum AnthropicDate { static func parse(_ string: String) -> Date? }` — handles the API's ISO-8601 with 6-digit fractional seconds (verified real format `2026-07-14T23:00:00.212361+00:00`) and plain ISO-8601.

- [ ] **Step 1: Write the failing test**

`Tests/AILimitBarKitTests/AnthropicDateTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

final class AnthropicDateTests: XCTestCase {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func testParsesFractionalSeconds() throws {
        let date = try XCTUnwrap(AnthropicDate.parse("2026-07-14T23:00:00.212361+00:00"))
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 7)
        XCTAssertEqual(parts.day, 14)
        XCTAssertEqual(parts.hour, 23)
        XCTAssertEqual(parts.minute, 0)
        XCTAssertEqual(parts.second, 0)
    }

    func testParsesPlainISO8601() throws {
        let date = try XCTUnwrap(AnthropicDate.parse("2026-07-16T21:00:00+00:00"))
        let parts = utc.dateComponents([.day, .hour], from: date)
        XCTAssertEqual(parts.day, 16)
        XCTAssertEqual(parts.hour, 21)
    }

    func testRejectsGarbage() {
        XCTAssertNil(AnthropicDate.parse("not-a-date"))
        XCTAssertNil(AnthropicDate.parse(""))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AnthropicDateTests`
Expected: FAIL — `cannot find 'AnthropicDate' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/AILimitBarKit/Core/AnthropicDate.swift`:
```swift
import Foundation

public enum AnthropicDate {
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parses API timestamps. ISO8601DateFormatter only accepts exactly 3
    /// fractional digits, while the API sends 6 — so fractions are truncated
    /// to milliseconds before parsing.
    public static func parse(_ string: String) -> Date? {
        if let d = plain.date(from: string) { return d }
        if let d = fractional.date(from: string) { return d }
        // Truncate long fractional seconds: ".212361" -> ".212"
        if let dotRange = string.range(of: #"\.\d+"#, options: .regularExpression) {
            let fraction = string[dotRange].dropFirst()
            let truncated = string.replacingCharacters(
                in: dotRange, with: "." + fraction.prefix(3))
            return fractional.date(from: truncated)
        }
        return nil
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AnthropicDateTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/Core/AnthropicDate.swift Tests/AILimitBarKitTests/AnthropicDateTests.swift
git commit -m "feat: tolerant ISO8601 parser for API timestamps"
```

---

### Task 4: Usage response decoding + mapping

**Files:**
- Create: `Sources/AILimitBarKit/Providers/Claude/UsageResponse.swift`
- Test: `Tests/AILimitBarKitTests/UsageResponseTests.swift`

**Interfaces:**
- Consumes: `AnthropicDate.parse`, `QuotaLimit`, `LimitKind` (Tasks 2-3).
- Produces:
  - `struct UsageResponse: Decodable` with `static func decode(_ data: Data) throws -> UsageResponse`
  - `func toQuotaLimits() -> [QuotaLimit]` — maps `limits[]`; skips unknown kinds; falls back to `five_hour`/`seven_day` when `limits` is missing/empty. Order: session, weeklyAll, weeklyModel…

- [ ] **Step 1: Write the failing test**

`Tests/AILimitBarKitTests/UsageResponseTests.swift` (fixtures mirror the real response captured 2026-07-15, values redacted):
```swift
import XCTest
@testable import AILimitBarKit

final class UsageResponseTests: XCTestCase {
    static let fullFixture = #"""
    {
      "five_hour": {"utilization": 10.0, "resets_at": "2026-07-14T23:00:00.212361+00:00"},
      "seven_day": {"utilization": 58.0, "resets_at": "2026-07-16T21:00:00.212431+00:00"},
      "seven_day_opus": null,
      "extra_usage": {"is_enabled": false},
      "limits": [
        {"kind": "session", "group": "session", "percent": 10, "severity": "normal",
         "resets_at": "2026-07-14T23:00:00.212361+00:00", "scope": null, "is_active": false},
        {"kind": "weekly_all", "group": "weekly", "percent": 58, "severity": "normal",
         "resets_at": "2026-07-16T21:00:00.212431+00:00", "scope": null, "is_active": true},
        {"kind": "weekly_scoped", "group": "weekly", "percent": 38, "severity": "normal",
         "resets_at": "2026-07-16T21:00:00.212804+00:00",
         "scope": {"model": {"id": null, "display_name": "Fable"}, "surface": null},
         "is_active": false}
      ]
    }
    """#

    static let legacyFixture = #"""
    {
      "five_hour": {"utilization": 22.0, "resets_at": "2026-07-14T23:00:00+00:00"},
      "seven_day": {"utilization": 71.0, "resets_at": "2026-07-16T21:00:00+00:00"}
    }
    """#

    static let unknownKindFixture = #"""
    {
      "limits": [
        {"kind": "hourly_quantum", "percent": 5, "resets_at": "2026-07-14T23:00:00+00:00", "is_active": false},
        {"kind": "session", "percent": 12, "resets_at": "2026-07-14T23:00:00+00:00", "is_active": true}
      ]
    }
    """#

    func testDecodesFullResponse() throws {
        let response = try UsageResponse.decode(Data(Self.fullFixture.utf8))
        let limits = response.toQuotaLimits()
        XCTAssertEqual(limits.count, 3)
        XCTAssertEqual(limits[0].kind, .session)
        XCTAssertEqual(limits[0].percentUsed, 10)
        XCTAssertFalse(limits[0].isActive)
        XCTAssertEqual(limits[1].kind, .weeklyAll)
        XCTAssertEqual(limits[1].percentUsed, 58)
        XCTAssertTrue(limits[1].isActive)
        XCTAssertEqual(limits[2].kind, .weeklyModel("Fable"))
        XCTAssertEqual(limits[2].percentUsed, 38)
    }

    func testFallsBackToLegacyFields() throws {
        let response = try UsageResponse.decode(Data(Self.legacyFixture.utf8))
        let limits = response.toQuotaLimits()
        XCTAssertEqual(limits.count, 2)
        XCTAssertEqual(limits[0].kind, .session)
        XCTAssertEqual(limits[0].percentUsed, 22)
        XCTAssertEqual(limits[1].kind, .weeklyAll)
        XCTAssertEqual(limits[1].percentUsed, 71)
    }

    func testSkipsUnknownKinds() throws {
        let response = try UsageResponse.decode(Data(Self.unknownKindFixture.utf8))
        let limits = response.toQuotaLimits()
        XCTAssertEqual(limits.count, 1)
        XCTAssertEqual(limits[0].kind, .session)
    }

    func testThrowsOnGarbage() {
        XCTAssertThrowsError(try UsageResponse.decode(Data("nope".utf8)))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter UsageResponseTests`
Expected: FAIL — `cannot find 'UsageResponse' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/AILimitBarKit/Providers/Claude/UsageResponse.swift`:
```swift
import Foundation

/// Wire format of GET https://api.anthropic.com/api/oauth/usage
/// (undocumented endpoint; every field optional for forward compatibility).
public struct UsageResponse: Decodable {
    public struct LimitEntry: Decodable {
        public let kind: String?
        public let percent: Double?
        public let resetsAt: String?
        public let isActive: Bool?
        public let scope: Scope?

        enum CodingKeys: String, CodingKey {
            case kind, percent, scope
            case resetsAt = "resets_at"
            case isActive = "is_active"
        }
    }

    public struct Scope: Decodable {
        public let model: Model?
        public struct Model: Decodable {
            public let displayName: String?
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }
    }

    public struct Window: Decodable {
        public let utilization: Double?
        public let resetsAt: String?
        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    public let limits: [LimitEntry]?
    public let fiveHour: Window?
    public let sevenDay: Window?

    enum CodingKeys: String, CodingKey {
        case limits
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    public static func decode(_ data: Data) throws -> UsageResponse {
        try JSONDecoder().decode(UsageResponse.self, from: data)
    }

    public func toQuotaLimits() -> [QuotaLimit] {
        let mapped = (limits ?? []).compactMap { entry -> QuotaLimit? in
            guard let percent = entry.percent,
                  let raw = entry.resetsAt,
                  let resetsAt = AnthropicDate.parse(raw) else { return nil }
            let kind: LimitKind
            switch entry.kind {
            case "session": kind = .session
            case "weekly_all": kind = .weeklyAll
            case "weekly_scoped":
                kind = .weeklyModel(entry.scope?.model?.displayName ?? "MODEL")
            default: return nil // unknown kinds skipped for forward compatibility
            }
            return QuotaLimit(kind: kind, percentUsed: percent,
                              resetsAt: resetsAt, isActive: entry.isActive ?? false)
        }
        if !mapped.isEmpty { return mapped.sorted(by: Self.displayOrder) }

        // Legacy fallback when limits[] is absent/empty.
        var fallback: [QuotaLimit] = []
        if let w = fiveHour, let pct = w.utilization,
           let raw = w.resetsAt, let date = AnthropicDate.parse(raw) {
            fallback.append(QuotaLimit(kind: .session, percentUsed: pct,
                                       resetsAt: date, isActive: false))
        }
        if let w = sevenDay, let pct = w.utilization,
           let raw = w.resetsAt, let date = AnthropicDate.parse(raw) {
            fallback.append(QuotaLimit(kind: .weeklyAll, percentUsed: pct,
                                       resetsAt: date, isActive: false))
        }
        return fallback
    }

    private static func displayOrder(_ a: QuotaLimit, _ b: QuotaLimit) -> Bool {
        func rank(_ kind: LimitKind) -> Int {
            switch kind {
            case .session: return 0
            case .weeklyAll: return 1
            case .weeklyModel: return 2
            }
        }
        return rank(a.kind) < rank(b.kind)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter UsageResponseTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/Providers Tests/AILimitBarKitTests/UsageResponseTests.swift
git commit -m "feat: usage response decoding with legacy fallback"
```

---

### Task 5: ResetFormatter

**Files:**
- Create: `Sources/AILimitBarKit/Core/ResetFormatter.swift`
- Test: `Tests/AILimitBarKitTests/ResetFormatterTests.swift`

**Interfaces:**
- Produces:
  - `ResetFormatter.sessionCountdown(until: Date, from: Date) -> String` → `"2H 14M"`, `"14M"`, `"<1M"`, `"NOW"` (past dates)
  - `ResetFormatter.weeklyReset(_ date: Date, timeZone: TimeZone) -> String` → `"THU 04:00"` (local time, EN weekday, part of the game aesthetic in both languages)

- [ ] **Step 1: Write the failing test**

`Tests/AILimitBarKitTests/ResetFormatterTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

final class ResetFormatterTests: XCTestCase {
    func testSessionCountdown() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        XCTAssertEqual(
            ResetFormatter.sessionCountdown(until: now.addingTimeInterval(2 * 3600 + 14 * 60), from: now),
            "2H 14M")
        XCTAssertEqual(
            ResetFormatter.sessionCountdown(until: now.addingTimeInterval(14 * 60), from: now),
            "14M")
        XCTAssertEqual(
            ResetFormatter.sessionCountdown(until: now.addingTimeInterval(30), from: now),
            "<1M")
        XCTAssertEqual(
            ResetFormatter.sessionCountdown(until: now.addingTimeInterval(-5), from: now),
            "NOW")
    }

    func testWeeklyReset() {
        // 2026-07-16T21:00:00Z is a Thursday; in UTC that renders THU 21:00.
        let date = Date(timeIntervalSince1970: 1_784_235_600)
        let utc = TimeZone(identifier: "UTC")!
        XCTAssertEqual(ResetFormatter.weeklyReset(date, timeZone: utc), "THU 21:00")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ResetFormatterTests`
Expected: FAIL — `cannot find 'ResetFormatter' in scope`.
(If the THU assertion fails with a different weekday once implemented, recompute: `1_784_235_600` = 2026-07-16 21:00:00 UTC. Verify with `date -u -r 1784235600` before changing the test.)

- [ ] **Step 3: Write minimal implementation**

`Sources/AILimitBarKit/Core/ResetFormatter.swift`:
```swift
import Foundation

public enum ResetFormatter {
    public static func sessionCountdown(until: Date, from now: Date) -> String {
        let remaining = until.timeIntervalSince(now)
        if remaining <= 0 { return "NOW" }
        let totalMinutes = Int(remaining / 60)
        if totalMinutes < 1 { return "<1M" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)H \(minutes)M" : "\(minutes)M"
    }

    public static func weeklyReset(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX") // EN weekday is part of the game look
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE HH:mm"
        return formatter.string(from: date).uppercased()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ResetFormatterTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/Core/ResetFormatter.swift Tests/AILimitBarKitTests/ResetFormatterTests.swift
git commit -m "feat: reset countdown and weekly reset formatting"
```

---

### Task 6: Credentials — parsing, sources, resolver, Keychain

**Files:**
- Create: `Sources/AILimitBarKit/Providers/Claude/ClaudeCredentials.swift`
- Test: `Tests/AILimitBarKitTests/ClaudeCredentialsTests.swift`

**Interfaces:**
- Produces:
  - `struct ClaudeCredentials { let accessToken: String; let expiresAt: Date; let subscriptionType: String?; static func parse(_ data: Data) -> ClaudeCredentials? }`
  - `protocol CredentialsSource { func load() -> ClaudeCredentials? }`
  - `struct FileCredentialsSource: CredentialsSource { init(path: String) }` (default path `~/.claude/.credentials.json`)
  - `struct KeychainCredentialsSource: CredentialsSource` (service `"Claude Code-credentials"`, read-only `SecItemCopyMatching`)
  - `struct CredentialsResolver { init(sources: [CredentialsSource]); func resolve() -> ClaudeCredentials? }` — picks newest `expiresAt`.

- [ ] **Step 1: Write the failing test**

`Tests/AILimitBarKitTests/ClaudeCredentialsTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

final class ClaudeCredentialsTests: XCTestCase {
    static let credentialsJSON = #"""
    {
      "claudeAiOauth": {
        "accessToken": "sk-test-token",
        "refreshToken": "rt-never-read",
        "expiresAt": 1784078801830,
        "refreshTokenExpiresAt": 1785604162830,
        "scopes": ["user:inference"],
        "subscriptionType": "max",
        "rateLimitTier": "default"
      },
      "mcpOAuth": {}
    }
    """#

    func testParse() throws {
        let creds = try XCTUnwrap(ClaudeCredentials.parse(Data(Self.credentialsJSON.utf8)))
        XCTAssertEqual(creds.accessToken, "sk-test-token")
        XCTAssertEqual(creds.expiresAt, Date(timeIntervalSince1970: 1784078801.830))
        XCTAssertEqual(creds.subscriptionType, "max")
    }

    func testParseRejectsMissingOauthBlock() {
        XCTAssertNil(ClaudeCredentials.parse(Data("{}".utf8)))
        XCTAssertNil(ClaudeCredentials.parse(Data("garbage".utf8)))
    }

    func testFileSourceReadsTempFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("creds.json")
        try Data(Self.credentialsJSON.utf8).write(to: file)
        let source = FileCredentialsSource(path: file.path)
        XCTAssertEqual(source.load()?.accessToken, "sk-test-token")
    }

    func testFileSourceMissingFileReturnsNil() {
        XCTAssertNil(FileCredentialsSource(path: "/nonexistent/creds.json").load())
    }

    func testResolverPicksNewestExpiry() {
        struct Stub: CredentialsSource {
            let creds: ClaudeCredentials?
            func load() -> ClaudeCredentials? { creds }
        }
        let older = ClaudeCredentials(accessToken: "old", expiresAt: Date(timeIntervalSince1970: 100), subscriptionType: nil)
        let newer = ClaudeCredentials(accessToken: "new", expiresAt: Date(timeIntervalSince1970: 200), subscriptionType: nil)
        let resolver = CredentialsResolver(sources: [Stub(creds: older), Stub(creds: newer), Stub(creds: nil)])
        XCTAssertEqual(resolver.resolve()?.accessToken, "new")
        XCTAssertNil(CredentialsResolver(sources: [Stub(creds: nil)]).resolve())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ClaudeCredentialsTests`
Expected: FAIL — `cannot find 'ClaudeCredentials' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/AILimitBarKit/Providers/Claude/ClaudeCredentials.swift`:
```swift
import Foundation
import Security

public struct ClaudeCredentials: Equatable, Sendable {
    public let accessToken: String
    public let expiresAt: Date
    public let subscriptionType: String?

    public init(accessToken: String, expiresAt: Date, subscriptionType: String?) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
        self.subscriptionType = subscriptionType
    }

    /// Parses Claude Code's credentials JSON. Reads accessToken/expiresAt/
    /// subscriptionType only — the refresh token is deliberately never touched.
    public static func parse(_ data: Data) -> ClaudeCredentials? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = root["claudeAiOauth"] as? [String: Any],
            let token = oauth["accessToken"] as? String, !token.isEmpty,
            let expiresMs = oauth["expiresAt"] as? Double
        else { return nil }
        return ClaudeCredentials(
            accessToken: token,
            expiresAt: Date(timeIntervalSince1970: expiresMs / 1000),
            subscriptionType: oauth["subscriptionType"] as? String)
    }
}

public protocol CredentialsSource: Sendable {
    func load() -> ClaudeCredentials?
}

public struct FileCredentialsSource: CredentialsSource {
    let path: String

    public init(path: String = NSString(string: "~/.claude/.credentials.json").expandingTildeInPath) {
        self.path = path
    }

    public func load() -> ClaudeCredentials? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return ClaudeCredentials.parse(data)
    }
}

/// Read-only lookup of Claude Code's Keychain item. First access triggers
/// macOS's standard "allow access" dialog — documented in the README.
public struct KeychainCredentialsSource: CredentialsSource {
    public init() {}

    public func load() -> ClaudeCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecAttrAccount as String: NSUserName(),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return ClaudeCredentials.parse(data)
    }
}

public struct CredentialsResolver: Sendable {
    let sources: [CredentialsSource]

    public init(sources: [CredentialsSource]) {
        self.sources = sources
    }

    public static var standard: CredentialsResolver {
        CredentialsResolver(sources: [KeychainCredentialsSource(), FileCredentialsSource()])
    }

    public func resolve() -> ClaudeCredentials? {
        sources.compactMap { $0.load() }.max { $0.expiresAt < $1.expiresAt }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ClaudeCredentialsTests`
Expected: PASS (5 tests). Keychain source has no unit test (requires the real Keychain); it is verified next step.

- [ ] **Step 5: Manual Keychain smoke check**

Run this one-off (compares our reader with the `security` CLI **without printing secrets**):
```bash
cat > /tmp/kc_smoke.swift <<'EOF'
import AILimitBarKit
let creds = KeychainCredentialsSource().load()
print("keychain loaded:", creds != nil, "| expiry:", creds.map { "\($0.expiresAt)" } ?? "-")
EOF
swift build && swift run --skip-build 2>/dev/null || true
swiftc -I .build/debug -L .build/debug -lAILimitBarKit /tmp/kc_smoke.swift -o /tmp/kc_smoke 2>/dev/null && /tmp/kc_smoke || echo "smoke: run inside app later (Task 15) if linking fails"
```
Expected: `keychain loaded: true | expiry: <a future date>` (a Keychain "Allow" prompt may appear — click Allow). If linking the one-off fails, defer verification to the app smoke test in Task 16; do not block.

- [ ] **Step 6: Commit**

```bash
git add Sources/AILimitBarKit/Providers/Claude/ClaudeCredentials.swift Tests/AILimitBarKitTests/ClaudeCredentialsTests.swift
git commit -m "feat: read-only Claude credentials (keychain-first, newest-expiry wins)"
```

---

### Task 7: ClaudeUsageClient + ClaudeProvider

**Files:**
- Create: `Sources/AILimitBarKit/Providers/Claude/ClaudeUsageClient.swift`
- Create: `Sources/AILimitBarKit/Providers/Claude/ClaudeProvider.swift`
- Test: `Tests/AILimitBarKitTests/ClaudeUsageClientTests.swift`
- Test: `Tests/AILimitBarKitTests/ClaudeProviderTests.swift`

**Interfaces:**
- Consumes: `UsageResponse` (Task 4), `CredentialsResolver`/`ClaudeCredentials` (Task 6), `QuotaProvider`, `QuotaError`, `QuotaSnapshot` (Task 2).
- Produces:
  - `struct ClaudeUsageClient { init(session: URLSession = .shared); func fetchUsage(accessToken: String) async throws -> UsageResponse }` — throws `QuotaError.tokenExpired` on 401, `.badResponse` on non-200/undecodable, `.network` on transport errors.
  - `struct ClaudeProvider: QuotaProvider { init(resolver: CredentialsResolver, client: ClaudeUsageClient, now: @Sendable () -> Date = { Date() }) }` — `id == "claude"`, plan name mapping `max→CLAUDE MAX`, `pro→CLAUDE PRO`, `team→CLAUDE TEAM`, `enterprise→CLAUDE ENTERPRISE`, else `CLAUDE`.

- [ ] **Step 1: Write the failing client test (URLProtocol mock)**

`Tests/AILimitBarKitTests/ClaudeUsageClientTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { fatalError("no handler") }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

final class ClaudeUsageClientTests: XCTestCase {
    private func makeClient() -> ClaudeUsageClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return ClaudeUsageClient(session: URLSession(configuration: config))
    }

    private func respond(status: Int, body: String) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        { request in
            (HTTPURLResponse(url: request.url!, statusCode: status,
                             httpVersion: nil, headerFields: nil)!,
             Data(body.utf8))
        }
    }

    func testSendsCorrectRequest() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        MockURLProtocol.handler = { request in
            captured = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!,
                    Data(UsageResponseTests.fullFixture.utf8))
        }
        _ = try await makeClient().fetchUsage(accessToken: "tok-123")
        XCTAssertEqual(captured?.url?.absoluteString, "https://api.anthropic.com/api/oauth/usage")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer tok-123")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
    }

    func testDecodes200() async throws {
        MockURLProtocol.handler = respond(status: 200, body: UsageResponseTests.fullFixture)
        let response = try await makeClient().fetchUsage(accessToken: "tok")
        XCTAssertEqual(response.toQuotaLimits().count, 3)
    }

    func test401ThrowsTokenExpired() async {
        MockURLProtocol.handler = respond(status: 401, body: #"{"type":"error"}"#)
        do {
            _ = try await makeClient().fetchUsage(accessToken: "tok")
            XCTFail("expected throw")
        } catch let error as QuotaError {
            XCTAssertEqual(error, .tokenExpired)
        } catch { XCTFail("wrong error \(error)") }
    }

    func test500ThrowsBadResponse() async {
        MockURLProtocol.handler = respond(status: 500, body: "oops")
        do {
            _ = try await makeClient().fetchUsage(accessToken: "tok")
            XCTFail("expected throw")
        } catch let error as QuotaError {
            guard case .badResponse = error else { return XCTFail("wrong case \(error)") }
        } catch { XCTFail("wrong error \(error)") }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ClaudeUsageClientTests`
Expected: FAIL — `cannot find 'ClaudeUsageClient' in scope`.

- [ ] **Step 3: Implement the client**

`Sources/AILimitBarKit/Providers/Claude/ClaudeUsageClient.swift`:
```swift
import Foundation

public struct ClaudeUsageClient: Sendable {
    public static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchUsage(accessToken: String) async throws -> UsageResponse {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw QuotaError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw QuotaError.badResponse("non-HTTP response")
        }
        switch http.statusCode {
        case 200:
            do { return try UsageResponse.decode(data) }
            catch { throw QuotaError.badResponse("decode failed: \(error)") }
        case 401, 403:
            throw QuotaError.tokenExpired
        default:
            throw QuotaError.badResponse("HTTP \(http.statusCode)")
        }
    }
}
```

- [ ] **Step 4: Run client tests to verify they pass**

Run: `swift test --filter ClaudeUsageClientTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Write the failing provider test**

`Tests/AILimitBarKitTests/ClaudeProviderTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

final class ClaudeProviderTests: XCTestCase {
    struct StubSource: CredentialsSource {
        let creds: ClaudeCredentials?
        func load() -> ClaudeCredentials? { creds }
    }

    private func provider(creds: ClaudeCredentials?,
                          respond: @escaping (URLRequest) throws -> (HTTPURLResponse, Data),
                          now: Date = Date(timeIntervalSince1970: 1_784_055_124)) -> ClaudeProvider {
        MockURLProtocol.handler = respond
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return ClaudeProvider(
            resolver: CredentialsResolver(sources: [StubSource(creds: creds)]),
            client: ClaudeUsageClient(session: URLSession(configuration: config)),
            now: { now })
    }

    private let validCreds = ClaudeCredentials(
        accessToken: "tok",
        expiresAt: Date(timeIntervalSince1970: 1_784_078_801), // future vs injected now
        subscriptionType: "max")

    func testFetchSnapshotSuccess() async throws {
        let p = provider(creds: validCreds, respond: { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data(UsageResponseTests.fullFixture.utf8))
        })
        let snapshot = try await p.fetchSnapshot()
        XCTAssertEqual(snapshot.planName, "CLAUDE MAX")
        XCTAssertEqual(snapshot.limits.count, 3)
    }

    func testMissingCredentialsThrows() async {
        let p = provider(creds: nil, respond: { _ in fatalError("must not be called") })
        do { _ = try await p.fetchSnapshot(); XCTFail("expected throw") }
        catch let e as QuotaError { XCTAssertEqual(e, .credentialsMissing) }
        catch { XCTFail("wrong error \(error)") }
    }

    func testLocallyExpiredTokenThrowsWithoutNetworkCall() async {
        let expired = ClaudeCredentials(
            accessToken: "tok",
            expiresAt: Date(timeIntervalSince1970: 1_784_000_000), // past vs injected now
            subscriptionType: "max")
        let p = provider(creds: expired, respond: { _ in fatalError("must not be called") })
        do { _ = try await p.fetchSnapshot(); XCTFail("expected throw") }
        catch let e as QuotaError { XCTAssertEqual(e, .tokenExpired) }
        catch { XCTFail("wrong error \(error)") }
    }

    func testPlanNames() {
        XCTAssertEqual(ClaudeProvider.planName(for: "max"), "CLAUDE MAX")
        XCTAssertEqual(ClaudeProvider.planName(for: "pro"), "CLAUDE PRO")
        XCTAssertEqual(ClaudeProvider.planName(for: "team"), "CLAUDE TEAM")
        XCTAssertEqual(ClaudeProvider.planName(for: "enterprise"), "CLAUDE ENTERPRISE")
        XCTAssertEqual(ClaudeProvider.planName(for: nil), "CLAUDE")
        XCTAssertEqual(ClaudeProvider.planName(for: "weird"), "CLAUDE")
    }
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `swift test --filter ClaudeProviderTests`
Expected: FAIL — `cannot find 'ClaudeProvider' in scope`.

- [ ] **Step 7: Implement the provider**

`Sources/AILimitBarKit/Providers/Claude/ClaudeProvider.swift`:
```swift
import Foundation

public struct ClaudeProvider: QuotaProvider {
    public let id = "claude"
    public let displayName = "CLAUDE"

    let resolver: CredentialsResolver
    let client: ClaudeUsageClient
    let now: @Sendable () -> Date

    public init(resolver: CredentialsResolver = .standard,
                client: ClaudeUsageClient = ClaudeUsageClient(),
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.resolver = resolver
        self.client = client
        self.now = now
    }

    public func fetchSnapshot() async throws -> QuotaSnapshot {
        guard let creds = resolver.resolve() else {
            throw QuotaError.credentialsMissing
        }
        guard creds.expiresAt > now() else {
            throw QuotaError.tokenExpired // don't waste a doomed network call
        }
        let response = try await client.fetchUsage(accessToken: creds.accessToken)
        return QuotaSnapshot(
            planName: Self.planName(for: creds.subscriptionType),
            limits: response.toQuotaLimits(),
            fetchedAt: now())
    }

    public static func planName(for subscriptionType: String?) -> String {
        switch subscriptionType {
        case "max": return "CLAUDE MAX"
        case "pro": return "CLAUDE PRO"
        case "team": return "CLAUDE TEAM"
        case "enterprise": return "CLAUDE ENTERPRISE"
        default: return "CLAUDE"
        }
    }
}
```

- [ ] **Step 8: Run all tests to verify they pass**

Run: `swift test`
Expected: PASS, no regressions.

- [ ] **Step 9: Commit**

```bash
git add Sources/AILimitBarKit/Providers Tests/AILimitBarKitTests/ClaudeUsageClientTests.swift Tests/AILimitBarKitTests/ClaudeProviderTests.swift
git commit -m "feat: Claude usage client and provider"
```

---

### Task 8: QuotaStore state machine

**Files:**
- Create: `Sources/AILimitBarKit/Core/QuotaStore.swift`
- Test: `Tests/AILimitBarKitTests/QuotaStoreTests.swift`

**Interfaces:**
- Consumes: `QuotaProvider`, `QuotaSnapshot`, `QuotaError` (Tasks 2, 7).
- Produces (all `@MainActor`):
  - `enum HeadlinePin: String, CaseIterable { case auto, session, weekly }`
  - `@Observable final class QuotaStore` with:
    - `enum State: Equatable { case loading, ready(QuotaSnapshot), credentialsMissing, tokenExpired, offline(last: QuotaSnapshot?) }`
    - `private(set) var state: State`
    - `var currentSnapshot: QuotaSnapshot?` (from `.ready` or `.offline(last:)`)
    - `func refresh() async`
    - `func refreshIfStale(olderThan seconds: TimeInterval) async` (default 10)
    - `func startPolling(interval: TimeInterval = 60)` / `func stopPolling()`
    - `func headlineLimit(pin: HeadlinePin) -> QuotaLimit?`
    - `static func retryDelay(failureCount: Int) -> TimeInterval` — 5·2^(n−1), capped 300.

- [ ] **Step 1: Write the failing test**

`Tests/AILimitBarKitTests/QuotaStoreTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

@MainActor
final class QuotaStoreTests: XCTestCase {
    final class ScriptedProvider: QuotaProvider, @unchecked Sendable {
        let id = "mock"
        let displayName = "MOCK"
        var script: [Result<QuotaSnapshot, QuotaError>] = []
        func fetchSnapshot() async throws -> QuotaSnapshot {
            switch script.removeFirst() {
            case .success(let snap): return snap
            case .failure(let error): throw error
            }
        }
    }

    private func snapshot(session: Double = 10, weekly: Double = 58,
                          fetchedAt: Date = Date()) -> QuotaSnapshot {
        QuotaSnapshot(planName: "CLAUDE MAX", limits: [
            QuotaLimit(kind: .session, percentUsed: session,
                       resetsAt: Date().addingTimeInterval(3600), isActive: false),
            QuotaLimit(kind: .weeklyAll, percentUsed: weekly,
                       resetsAt: Date().addingTimeInterval(86_400), isActive: true),
            QuotaLimit(kind: .weeklyModel("Fable"), percentUsed: 38,
                       resetsAt: Date().addingTimeInterval(86_400), isActive: false),
        ], fetchedAt: fetchedAt)
    }

    func testLoadingToReady() async {
        let provider = ScriptedProvider()
        provider.script = [.success(snapshot())]
        let store = QuotaStore(provider: provider)
        XCTAssertEqual(store.state, .loading)
        await store.refresh()
        XCTAssertEqual(store.state, .ready(store.currentSnapshot!))
        XCTAssertEqual(store.currentSnapshot?.limits.count, 3)
    }

    func testTokenExpiredAndRecovery() async {
        let provider = ScriptedProvider()
        provider.script = [.failure(.tokenExpired), .success(snapshot())]
        let store = QuotaStore(provider: provider)
        await store.refresh()
        XCTAssertEqual(store.state, .tokenExpired)
        await store.refresh()
        guard case .ready = store.state else { return XCTFail("should recover") }
    }

    func testCredentialsMissing() async {
        let provider = ScriptedProvider()
        provider.script = [.failure(.credentialsMissing)]
        let store = QuotaStore(provider: provider)
        await store.refresh()
        XCTAssertEqual(store.state, .credentialsMissing)
    }

    func testNetworkErrorKeepsLastSnapshot() async {
        let provider = ScriptedProvider()
        let snap = snapshot()
        provider.script = [.success(snap), .failure(.network("down"))]
        let store = QuotaStore(provider: provider)
        await store.refresh()
        await store.refresh()
        XCTAssertEqual(store.state, .offline(last: snap))
        XCTAssertEqual(store.currentSnapshot, snap)
    }

    func testHeadlineSelection() async {
        let provider = ScriptedProvider()
        provider.script = [.success(snapshot(session: 10, weekly: 58))]
        let store = QuotaStore(provider: provider)
        await store.refresh()
        XCTAssertEqual(store.headlineLimit(pin: .auto)?.percentUsed, 58)   // max wins
        XCTAssertEqual(store.headlineLimit(pin: .session)?.kind, .session)
        XCTAssertEqual(store.headlineLimit(pin: .weekly)?.kind, .weeklyAll)
    }

    func testRefreshIfStaleSkipsFreshData() async {
        let provider = ScriptedProvider()
        provider.script = [.success(snapshot(fetchedAt: Date()))] // only ONE scripted result
        let store = QuotaStore(provider: provider)
        await store.refresh()
        await store.refreshIfStale(olderThan: 10) // fresh -> must NOT fetch again
        guard case .ready = store.state else { return XCTFail() }
    }

    func testRetryDelayBackoff() {
        XCTAssertEqual(QuotaStore.retryDelay(failureCount: 1), 5)
        XCTAssertEqual(QuotaStore.retryDelay(failureCount: 2), 10)
        XCTAssertEqual(QuotaStore.retryDelay(failureCount: 4), 40)
        XCTAssertEqual(QuotaStore.retryDelay(failureCount: 10), 300) // capped
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter QuotaStoreTests`
Expected: FAIL — `cannot find 'QuotaStore' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/AILimitBarKit/Core/QuotaStore.swift`:
```swift
import Foundation
import Observation

public enum HeadlinePin: String, CaseIterable, Sendable {
    case auto, session, weekly
}

@MainActor
@Observable
public final class QuotaStore {
    public enum State: Equatable {
        case loading
        case ready(QuotaSnapshot)
        case credentialsMissing
        case tokenExpired
        case offline(last: QuotaSnapshot?)
    }

    public private(set) var state: State = .loading

    private let provider: QuotaProvider
    private var lastGood: QuotaSnapshot?
    private var failureCount = 0
    private var pollTimer: Timer?
    private var retryTimer: Timer?

    public init(provider: QuotaProvider) {
        self.provider = provider
    }

    public var currentSnapshot: QuotaSnapshot? {
        switch state {
        case .ready(let snap): return snap
        case .offline(let last): return last
        default: return nil
        }
    }

    public func refresh() async {
        do {
            let snapshot = try await provider.fetchSnapshot()
            lastGood = snapshot
            failureCount = 0
            retryTimer?.invalidate()
            state = .ready(snapshot)
        } catch let error as QuotaError {
            switch error {
            case .credentialsMissing:
                state = .credentialsMissing
            case .tokenExpired:
                state = .tokenExpired
            case .network, .badResponse:
                failureCount += 1
                state = .offline(last: lastGood)
                scheduleRetry()
            }
        } catch {
            failureCount += 1
            state = .offline(last: lastGood)
            scheduleRetry()
        }
    }

    public func refreshIfStale(olderThan seconds: TimeInterval = 10) async {
        if let snap = currentSnapshot,
           Date().timeIntervalSince(snap.fetchedAt) < seconds,
           case .ready = state {
            return
        }
        await refresh()
    }

    public func startPolling(interval: TimeInterval = 60) {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        retryTimer?.invalidate()
        retryTimer = nil
    }

    private func scheduleRetry() {
        retryTimer?.invalidate()
        let delay = Self.retryDelay(failureCount: failureCount)
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    public func headlineLimit(pin: HeadlinePin) -> QuotaLimit? {
        guard let limits = currentSnapshot?.limits, !limits.isEmpty else { return nil }
        switch pin {
        case .auto:
            return limits.max { $0.percentUsed < $1.percentUsed }
        case .session:
            return limits.first { $0.kind == .session } ?? limits.first
        case .weekly:
            return limits.first { $0.kind == .weeklyAll } ?? limits.first
        }
    }

    public static func retryDelay(failureCount: Int) -> TimeInterval {
        min(5 * pow(2, Double(max(failureCount, 1) - 1)), 300)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter QuotaStoreTests`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/Core/QuotaStore.swift Tests/AILimitBarKitTests/QuotaStoreTests.swift
git commit -m "feat: QuotaStore state machine with backoff and headline selection"
```

---

### Task 9: AppSettings persistence

**Files:**
- Create: `Sources/AILimitBarKit/Core/AppSettings.swift`
- Test: `Tests/AILimitBarKitTests/AppSettingsTests.swift`

**Interfaces:**
- Consumes: `HeadlinePin` (Task 8).
- Produces (all `@MainActor` unless enum):
  - `enum AppLanguage: String, CaseIterable { case en, th }`
  - `enum ThemePreference: String, CaseIterable { case system, dark, light }`
  - `enum AvatarID: String, CaseIterable { case boo, bug, bot }`
  - `@Observable final class AppSettings { init(defaults: UserDefaults = .standard) }` with persisted properties:
    `language: AppLanguage` (default `.en`), `theme: ThemePreference` (default `.system`),
    `showPercentInMenuBar: Bool` (true), `headlinePin: HeadlinePin` (`.auto`),
    `showSession/showWeeklyAll/showWeeklyModels: Bool` (all true),
    `compactRows: Bool` (false), `avatar: AvatarID` (`.boo`).
  - `func isVisible(_ kind: LimitKind) -> Bool`

- [ ] **Step 1: Write the failing test**

`Tests/AILimitBarKitTests/AppSettingsTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

@MainActor
final class AppSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "AppSettingsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    func testDefaults() {
        let s = AppSettings(defaults: defaults)
        XCTAssertEqual(s.language, .en)
        XCTAssertEqual(s.theme, .system)
        XCTAssertTrue(s.showPercentInMenuBar)
        XCTAssertEqual(s.headlinePin, .auto)
        XCTAssertTrue(s.showSession)
        XCTAssertTrue(s.showWeeklyAll)
        XCTAssertTrue(s.showWeeklyModels)
        XCTAssertFalse(s.compactRows)
        XCTAssertEqual(s.avatar, .boo)
    }

    func testPersistsAcrossInstances() {
        let s1 = AppSettings(defaults: defaults)
        s1.language = .th
        s1.theme = .dark
        s1.showPercentInMenuBar = false
        s1.headlinePin = .session
        s1.showWeeklyModels = false
        s1.compactRows = true
        s1.avatar = .bot

        let s2 = AppSettings(defaults: defaults)
        XCTAssertEqual(s2.language, .th)
        XCTAssertEqual(s2.theme, .dark)
        XCTAssertFalse(s2.showPercentInMenuBar)
        XCTAssertEqual(s2.headlinePin, .session)
        XCTAssertFalse(s2.showWeeklyModels)
        XCTAssertTrue(s2.compactRows)
        XCTAssertEqual(s2.avatar, .bot)
    }

    func testVisibility() {
        let s = AppSettings(defaults: defaults)
        s.showSession = false
        XCTAssertFalse(s.isVisible(.session))
        XCTAssertTrue(s.isVisible(.weeklyAll))
        s.showWeeklyModels = false
        XCTAssertFalse(s.isVisible(.weeklyModel("Fable")))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AppSettingsTests`
Expected: FAIL — `cannot find 'AppSettings' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/AILimitBarKit/Core/AppSettings.swift`:
```swift
import Foundation
import Observation

public enum AppLanguage: String, CaseIterable, Sendable { case en, th }
public enum ThemePreference: String, CaseIterable, Sendable { case system, dark, light }
public enum AvatarID: String, CaseIterable, Sendable { case boo, bug, bot }

@MainActor
@Observable
public final class AppSettings {
    private let defaults: UserDefaults

    public var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: "language") } }
    public var theme: ThemePreference { didSet { defaults.set(theme.rawValue, forKey: "theme") } }
    public var showPercentInMenuBar: Bool { didSet { defaults.set(showPercentInMenuBar, forKey: "showPercentInMenuBar") } }
    public var headlinePin: HeadlinePin { didSet { defaults.set(headlinePin.rawValue, forKey: "headlinePin") } }
    public var showSession: Bool { didSet { defaults.set(showSession, forKey: "showSession") } }
    public var showWeeklyAll: Bool { didSet { defaults.set(showWeeklyAll, forKey: "showWeeklyAll") } }
    public var showWeeklyModels: Bool { didSet { defaults.set(showWeeklyModels, forKey: "showWeeklyModels") } }
    public var compactRows: Bool { didSet { defaults.set(compactRows, forKey: "compactRows") } }
    public var avatar: AvatarID { didSet { defaults.set(avatar.rawValue, forKey: "avatar") } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .en
        theme = ThemePreference(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system
        showPercentInMenuBar = defaults.object(forKey: "showPercentInMenuBar") as? Bool ?? true
        headlinePin = HeadlinePin(rawValue: defaults.string(forKey: "headlinePin") ?? "") ?? .auto
        showSession = defaults.object(forKey: "showSession") as? Bool ?? true
        showWeeklyAll = defaults.object(forKey: "showWeeklyAll") as? Bool ?? true
        showWeeklyModels = defaults.object(forKey: "showWeeklyModels") as? Bool ?? true
        compactRows = defaults.object(forKey: "compactRows") as? Bool ?? false
        avatar = AvatarID(rawValue: defaults.string(forKey: "avatar") ?? "") ?? .boo
    }

    public func isVisible(_ kind: LimitKind) -> Bool {
        switch kind {
        case .session: return showSession
        case .weeklyAll: return showWeeklyAll
        case .weeklyModel: return showWeeklyModels
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AppSettingsTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/Core/AppSettings.swift Tests/AILimitBarKitTests/AppSettingsTests.swift
git commit -m "feat: persisted app settings"
```

---

### Task 10: L10n EN/TH string table

**Files:**
- Create: `Sources/AILimitBarKit/Core/L10n.swift`
- Test: `Tests/AILimitBarKitTests/L10nTests.swift`

**Interfaces:**
- Consumes: `AppLanguage` (Task 9).
- Produces: `enum L10nKey: String, CaseIterable` and `enum L10n { static func t(_ key: L10nKey, _ lang: AppLanguage) -> String }`. A hand-rolled table (not String Catalog) because the in-app language toggle must switch at runtime, independent of system locale.

- [ ] **Step 1: Write the failing test**

`Tests/AILimitBarKitTests/L10nTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

final class L10nTests: XCTestCase {
    func testEveryKeyHasBothLanguages() {
        for key in L10nKey.allCases {
            XCTAssertFalse(L10n.t(key, .en).isEmpty, "missing EN for \(key)")
            XCTAssertFalse(L10n.t(key, .th).isEmpty, "missing TH for \(key)")
        }
    }

    func testSample() {
        XCTAssertEqual(L10n.t(.settingsLanguage, .en), "Language")
        XCTAssertEqual(L10n.t(.settingsLanguage, .th), "ภาษา")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter L10nTests`
Expected: FAIL — `cannot find 'L10n' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/AILimitBarKit/Core/L10n.swift`:
```swift
import Foundation

public enum L10nKey: String, CaseIterable, Sendable {
    // Settings window
    case settingsTitle, settingsGeneral, settingsDisplay, settingsAvatar
    case settingsLanguage, settingsTheme
    case themeSystem, themeDark, themeLight
    case showPercent, visibleLimits, headlinePinLabel
    case pinAuto, pinSession, pinWeekly
    case compactRows, chooseAvatar
    case limitSession, limitWeeklyAll, limitWeeklyModels
    // Popover states
    case hintInstallClaude, hintTokenExpired, offlineLastUpdated, loadingHint
}

public enum L10n {
    public static func t(_ key: L10nKey, _ lang: AppLanguage) -> String {
        (lang == .en ? en[key] : th[key]) ?? key.rawValue
    }

    private static let en: [L10nKey: String] = [
        .settingsTitle: "Settings",
        .settingsGeneral: "General",
        .settingsDisplay: "Display",
        .settingsAvatar: "Avatar",
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
        .chooseAvatar: "Choose your avatar",
        .limitSession: "Session (5-hour)",
        .limitWeeklyAll: "Weekly (all models)",
        .limitWeeklyModels: "Weekly (per model)",
        .hintInstallClaude: "Install and sign in to Claude Code first — this app reads its quota data.",
        .hintTokenExpired: "Use Claude Code once to renew the token, then this app recovers automatically.",
        .offlineLastUpdated: "Last updated",
        .loadingHint: "Loading quota…",
    ]

    private static let th: [L10nKey: String] = [
        .settingsTitle: "ตั้งค่า",
        .settingsGeneral: "ทั่วไป",
        .settingsDisplay: "การแสดงผล",
        .settingsAvatar: "อวตาร",
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
        .chooseAvatar: "เลือกอวตารของคุณ",
        .limitSession: "รอบ 5 ชั่วโมง",
        .limitWeeklyAll: "รายสัปดาห์ (ทุกโมเดล)",
        .limitWeeklyModels: "รายสัปดาห์ (รายโมเดล)",
        .hintInstallClaude: "ติดตั้งและล็อกอิน Claude Code ก่อน — แอปนี้อ่านข้อมูลโควต้าจาก Claude Code",
        .hintTokenExpired: "เปิดใช้ Claude Code หนึ่งครั้งเพื่อต่ออายุ token แล้วแอปจะกลับมาทำงานเอง",
        .offlineLastUpdated: "อัปเดตล่าสุด",
        .loadingHint: "กำลังโหลดโควต้า…",
    ]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter L10nTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/Core/L10n.swift Tests/AILimitBarKitTests/L10nTests.swift
git commit -m "feat: EN/TH string table with runtime switching"
```

---

### Task 11: RetroTheme + PixelFont

**Files:**
- Create: `Sources/AILimitBarKit/UI/Retro/RetroTheme.swift`
- Create: `Sources/AILimitBarKit/UI/Retro/PixelFont.swift`
- Create: `Sources/AILimitBarKit/Resources/Fonts/PressStart2P-Regular.ttf` (downloaded)
- Create: `Sources/AILimitBarKit/Resources/Fonts/OFL.txt` (license, downloaded)
- Modify: `Package.swift` (add resources to `AILimitBarKit` target)
- Test: `Tests/AILimitBarKitTests/RetroThemeTests.swift`

**Interfaces:**
- Consumes: `Severity` (Task 2), `ThemePreference` (Task 9).
- Produces:
  - `struct RetroPalette { let background, surface, textPrimary, accentPink, accentCyan, ok, warn, critical: Color }`
  - `enum RetroTheme { static let dark: RetroPalette; static let light: RetroPalette; static func palette(_ pref: ThemePreference, systemIsDark: Bool) -> RetroPalette; static func color(for severity: Severity, in palette: RetroPalette) -> Color }`
  - `enum PixelFont { static let fontName = "Press Start 2P"; static func registerBundledFont(); static func swiftUI(size: CGFloat) -> Font; static func nsFont(size: CGFloat) -> NSFont }` (falls back to monospaced system font when registration fails)

- [ ] **Step 1: Download the font + license**

```bash
mkdir -p Sources/AILimitBarKit/Resources/Fonts
curl -fsSL -o Sources/AILimitBarKit/Resources/Fonts/PressStart2P-Regular.ttf \
  "https://github.com/google/fonts/raw/main/ofl/pressstart2p/PressStart2P-Regular.ttf"
curl -fsSL -o Sources/AILimitBarKit/Resources/Fonts/OFL.txt \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/pressstart2p/OFL.txt"
file Sources/AILimitBarKit/Resources/Fonts/PressStart2P-Regular.ttf
```
Expected: `TrueType Font data`. If the URL 404s, find the current path with `curl -s https://api.github.com/repos/google/fonts/contents/ofl/pressstart2p | jq -r '.[].name'`.

- [ ] **Step 2: Add resources to Package.swift**

In `Package.swift`, change the `AILimitBarKit` target to:
```swift
        .target(
            name: "AILimitBarKit",
            path: "Sources/AILimitBarKit",
            resources: [.copy("Resources/Fonts")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
```

- [ ] **Step 3: Write the failing test**

`Tests/AILimitBarKitTests/RetroThemeTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import AILimitBarKit

final class RetroThemeTests: XCTestCase {
    func testSeverityColorMapping() {
        let p = RetroTheme.dark
        XCTAssertEqual(RetroTheme.color(for: .ok, in: p), p.ok)
        XCTAssertEqual(RetroTheme.color(for: .warn, in: p), p.warn)
        XCTAssertEqual(RetroTheme.color(for: .critical, in: p), p.critical)
    }

    func testPaletteSelection() {
        XCTAssertEqual(RetroTheme.palette(.dark, systemIsDark: false).background,
                       RetroTheme.dark.background)
        XCTAssertEqual(RetroTheme.palette(.light, systemIsDark: true).background,
                       RetroTheme.light.background)
        XCTAssertEqual(RetroTheme.palette(.system, systemIsDark: true).background,
                       RetroTheme.dark.background)
        XCTAssertEqual(RetroTheme.palette(.system, systemIsDark: false).background,
                       RetroTheme.light.background)
    }

    func testFontRegistration() {
        PixelFont.registerBundledFont()
        // After registration the PostScript/display name must resolve.
        XCTAssertNotNil(NSFont(name: "Press Start 2P", size: 12) ?? NSFont(name: "PressStart2P-Regular", size: 12))
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `swift test --filter RetroThemeTests`
Expected: FAIL — `cannot find 'RetroTheme' in scope`.

- [ ] **Step 5: Write minimal implementation**

`Sources/AILimitBarKit/UI/Retro/RetroTheme.swift`:
```swift
import SwiftUI

public struct RetroPalette: Equatable, Sendable {
    public let background: Color
    public let surface: Color
    public let textPrimary: Color
    public let accentPink: Color
    public let accentCyan: Color
    public let ok: Color
    public let warn: Color
    public let critical: Color
}

public enum RetroTheme {
    public static let dark = RetroPalette(
        background: Color(hex: 0x0A0A12),
        surface: Color(hex: 0x16161F),
        textPrimary: Color(hex: 0xE8E8F0),
        accentPink: Color(hex: 0xFF2E88),
        accentCyan: Color(hex: 0x00CCFF),
        ok: Color(hex: 0x00FF66),
        warn: Color(hex: 0xFFD500),
        critical: Color(hex: 0xFF3344))

    public static let light = RetroPalette(
        background: Color(hex: 0xF2EAD3),
        surface: Color(hex: 0xE6DCC0),
        textPrimary: Color(hex: 0x2B2B33),
        accentPink: Color(hex: 0xB0246A),
        accentCyan: Color(hex: 0x00708C),
        ok: Color(hex: 0x1D7A3E),
        warn: Color(hex: 0x9A6B00),
        critical: Color(hex: 0xB3232E))

    public static func palette(_ pref: ThemePreference, systemIsDark: Bool) -> RetroPalette {
        switch pref {
        case .dark: return dark
        case .light: return light
        case .system: return systemIsDark ? dark : light
        }
    }

    public static func color(for severity: Severity, in palette: RetroPalette) -> Color {
        switch severity {
        case .ok: return palette.ok
        case .warn: return palette.warn
        case .critical: return palette.critical
        }
    }
}

public extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}
```

`Sources/AILimitBarKit/UI/Retro/PixelFont.swift`:
```swift
import AppKit
import SwiftUI
import CoreText

public enum PixelFont {
    public static let fontName = "Press Start 2P"
    private nonisolated(unsafe) static var registered = false

    public static func registerBundledFont() {
        guard !registered else { return }
        registered = true
        guard let url = Bundle.module.url(forResource: "PressStart2P-Regular",
                                          withExtension: "ttf",
                                          subdirectory: "Fonts") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    public static func nsFont(size: CGFloat) -> NSFont {
        registerBundledFont()
        return NSFont(name: fontName, size: size)
            ?? NSFont(name: "PressStart2P-Regular", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }

    public static func swiftUI(size: CGFloat) -> Font {
        registerBundledFont()
        return Font.custom(fontName, size: size)
    }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `swift test --filter RetroThemeTests`
Expected: PASS (3 tests). If `testFontRegistration` fails, check `Bundle.module` subdirectory handling: with `.copy("Resources/Fonts")` the URL is `url(forResource:"PressStart2P-Regular", withExtension:"ttf", subdirectory:"Fonts")`. Print `Bundle.module.resourceURL` to debug.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/AILimitBarKit/UI/Retro Sources/AILimitBarKit/Resources Tests/AILimitBarKitTests/RetroThemeTests.swift
git commit -m "feat: retro palettes and bundled Press Start 2P pixel font (OFL)"
```

---

### Task 12: Sprites — BOO / BUG / BOT

**Files:**
- Create: `Sources/AILimitBarKit/UI/Retro/Sprite.swift`
- Create: `Sources/AILimitBarKit/UI/Retro/SpriteLibrary.swift`
- Test: `Tests/AILimitBarKitTests/SpriteTests.swift`

**Interfaces:**
- Consumes: `AvatarID` (Task 9).
- Produces:
  - `struct SpriteFrame { init(rows: [String]); let bitmap: [[Bool]] }` — `"#"` = filled, anything else empty; 16×16.
  - `struct Sprite { let id: AvatarID; let frames: [SpriteFrame] }` — `frames.count == 4` (loop: base, alt, base, blink); `var menuBarFrames: [SpriteFrame]` = first 2.
  - `enum SpriteLibrary { static func sprite(for id: AvatarID) -> Sprite }`
  - `extension SpriteFrame { func nsImage(color: NSColor, pixelSize: CGFloat) -> NSImage }`

- [ ] **Step 1: Write the failing test**

`Tests/AILimitBarKitTests/SpriteTests.swift`:
```swift
import XCTest
import AppKit
@testable import AILimitBarKit

final class SpriteTests: XCTestCase {
    func testAllSpritesAre16x16With4Frames() {
        for id in AvatarID.allCases {
            let sprite = SpriteLibrary.sprite(for: id)
            XCTAssertEqual(sprite.id, id)
            XCTAssertEqual(sprite.frames.count, 4, "\(id) needs 4 popover frames")
            XCTAssertEqual(sprite.menuBarFrames.count, 2)
            for (i, frame) in sprite.frames.enumerated() {
                XCTAssertEqual(frame.bitmap.count, 16, "\(id) frame \(i) rows")
                for row in frame.bitmap { XCTAssertEqual(row.count, 16, "\(id) frame \(i) cols") }
            }
        }
    }

    func testFramesAreNotAllIdentical() {
        for id in AvatarID.allCases {
            let sprite = SpriteLibrary.sprite(for: id)
            XCTAssertNotEqual(sprite.frames[0].bitmap, sprite.frames[1].bitmap,
                              "\(id) idle animation needs 2 distinct frames")
        }
    }

    func testNSImageRendering() {
        let frame = SpriteLibrary.sprite(for: .boo).frames[0]
        let image = frame.nsImage(color: .systemGreen, pixelSize: 1)
        XCTAssertEqual(image.size, NSSize(width: 16, height: 16))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SpriteTests`
Expected: FAIL — `cannot find 'SpriteLibrary' in scope`.

- [ ] **Step 3: Implement Sprite + renderer**

`Sources/AILimitBarKit/UI/Retro/Sprite.swift`:
```swift
import AppKit

public struct SpriteFrame: Equatable, Sendable {
    public let bitmap: [[Bool]] // 16 rows x 16 cols

    public init(rows: [String]) {
        precondition(rows.count == 16, "sprite must have 16 rows")
        bitmap = rows.map { row -> [Bool] in
            precondition(row.count == 16, "sprite row must have 16 chars")
            return row.map { $0 == "#" }
        }
    }

    public func nsImage(color: NSColor, pixelSize: CGFloat) -> NSImage {
        let side = 16 * pixelSize
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        color.setFill()
        for (y, row) in bitmap.enumerated() {
            for (x, filled) in row.enumerated() where filled {
                // NSImage origin is bottom-left; sprite rows are top-down.
                NSRect(x: CGFloat(x) * pixelSize,
                       y: side - CGFloat(y + 1) * pixelSize,
                       width: pixelSize, height: pixelSize).fill()
            }
        }
        image.unlockFocus()
        return image
    }
}

public struct Sprite: Sendable {
    public let id: AvatarID
    public let frames: [SpriteFrame] // 4-frame popover loop

    public var menuBarFrames: [SpriteFrame] { Array(frames.prefix(2)) }

    public init(id: AvatarID, base: SpriteFrame, alt: SpriteFrame, blink: SpriteFrame) {
        self.id = id
        self.frames = [base, alt, base, blink]
    }
}
```

`Sources/AILimitBarKit/UI/Retro/SpriteLibrary.swift` (original pixel art — executor may fine-tune shapes, but keep 16×16 and the test invariants):
```swift
import Foundation

public enum SpriteLibrary {
    public static func sprite(for id: AvatarID) -> Sprite {
        switch id {
        case .boo: return boo
        case .bug: return bug
        case .bot: return bot
        }
    }

    // BOO — ghost. base: wavy tail A, alt: wavy tail B, blink: eyes shut.
    static let boo = Sprite(
        id: .boo,
        base: SpriteFrame(rows: [
            "................",
            ".....######.....",
            "...##########...",
            "..############..",
            "..##..####..##..",
            ".###..####..###.",
            ".##############.",
            ".##############.",
            ".##############.",
            ".##############.",
            ".##############.",
            ".##############.",
            ".##.###..###.##.",
            ".#...##...##..#.",
            "................",
            "................",
        ]),
        alt: SpriteFrame(rows: [
            "................",
            ".....######.....",
            "...##########...",
            "..############..",
            "..##..####..##..",
            ".###..####..###.",
            ".##############.",
            ".##############.",
            ".##############.",
            ".##############.",
            ".##############.",
            ".##############.",
            ".#.###..###..##.",
            ".#..##...##...#.",
            "................",
            "................",
        ]),
        blink: SpriteFrame(rows: [
            "................",
            ".....######.....",
            "...##########...",
            "..############..",
            "..############..",
            ".####..##..####.",
            ".##############.",
            ".##############.",
            ".##############.",
            ".##############.",
            ".##############.",
            ".##############.",
            ".##.###..###.##.",
            ".#...##...##..#.",
            "................",
            "................",
        ]))

    // BUG — alien. base: arms down, alt: arms up, blink: eyes wide.
    static let bug = Sprite(
        id: .bug,
        base: SpriteFrame(rows: [
            "................",
            "....#......#....",
            ".....#....#.....",
            "....########....",
            "...##########...",
            "..###.####.###..",
            ".##############.",
            ".#.##########.#.",
            ".#.#........#.#.",
            "....##....##....",
            "...##......##...",
            "................",
            "................",
            "................",
            "................",
            "................",
        ]),
        alt: SpriteFrame(rows: [
            "................",
            "....#......#....",
            ".....#....#.....",
            "....########....",
            "...##########...",
            "..###.####.###..",
            ".##############.",
            "##.##########.##",
            "#..#........#..#",
            "....##....##....",
            "....#......#....",
            "................",
            "................",
            "................",
            "................",
            "................",
        ]),
        blink: SpriteFrame(rows: [
            "................",
            "....#......#....",
            ".....#....#.....",
            "....########....",
            "...##########...",
            "..##.#.##.#.##..",
            ".##############.",
            ".#.##########.#.",
            ".#.#........#.#.",
            "....##....##....",
            "...##......##...",
            "................",
            "................",
            "................",
            "................",
            "................",
        ]))

    // BOT — robot. base: antenna up, alt: antenna tilt, blink: eyes off.
    static let bot = Sprite(
        id: .bot,
        base: SpriteFrame(rows: [
            ".......#........",
            ".......#........",
            "......###.......",
            "..############..",
            "..#..........#..",
            "..#.###..###.#..",
            "..#.###..###.#..",
            "..#..........#..",
            "..#..######..#..",
            "..############..",
            "....##....##....",
            "...####..####...",
            "................",
            "................",
            "................",
            "................",
        ]),
        alt: SpriteFrame(rows: [
            "........#.......",
            ".......#........",
            "......###.......",
            "..############..",
            "..#..........#..",
            "..#.###..###.#..",
            "..#.###..###.#..",
            "..#..........#..",
            "..#..######..#..",
            "..############..",
            "....##....##....",
            "...####..####...",
            "................",
            "................",
            "................",
            "................",
        ]),
        blink: SpriteFrame(rows: [
            ".......#........",
            ".......#........",
            "......###.......",
            "..############..",
            "..#..........#..",
            "..#..........#..",
            "..#.###..###.#..",
            "..#..........#..",
            "..#..######..#..",
            "..############..",
            "....##....##....",
            "...####..####...",
            "................",
            "................",
            "................",
            "................",
        ]))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SpriteTests`
Expected: PASS (3 tests). Precondition failures mean a row is not exactly 16 chars — count carefully.

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/UI/Retro/Sprite.swift Sources/AILimitBarKit/UI/Retro/SpriteLibrary.swift Tests/AILimitBarKitTests/SpriteTests.swift
git commit -m "feat: original 16x16 pixel avatars BOO/BUG/BOT with idle+blink frames"
```

---

### Task 13: Retro UI components

**Files:**
- Create: `Sources/AILimitBarKit/UI/Retro/PixelProgressBar.swift`
- Create: `Sources/AILimitBarKit/UI/Retro/AvatarSpriteView.swift`
- Create: `Sources/AILimitBarKit/UI/Popover/LimitRowView.swift`
- Test: `Tests/AILimitBarKitTests/UIComponentLogicTests.swift`

**Interfaces:**
- Consumes: `RetroPalette`, `PixelFont`, `Sprite`, `QuotaLimit`, `Severity`, `ResetFormatter` (Tasks 2, 5, 11, 12).
- Produces:
  - `struct PixelProgressBar: View { init(percent: Double, palette: RetroPalette); static func filledSegments(percent: Double, total: Int) -> Int }`
  - `struct AvatarSpriteView: View { init(sprite: Sprite, color: Color, pixelScale: CGFloat) }` — TimelineView 0.3 s frame loop via Canvas.
  - `struct LimitRowView: View { init(limit: QuotaLimit, palette: RetroPalette, compact: Bool, now: Date) }`
  - `LimitRowView.kindLabel(_ kind: LimitKind) -> String` → `"SESSION"`, `"WEEKLY ALL"`, `"WEEKLY FABLE"` (uppercased model).
  - `LimitRowView.resetLabel(for limit: QuotaLimit, now: Date) -> String` → session: `"RESET 2H 14M"`; weekly: `"RESET THU 04:00"`.

- [ ] **Step 1: Write the failing test**

`Tests/AILimitBarKitTests/UIComponentLogicTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

final class UIComponentLogicTests: XCTestCase {
    func testFilledSegments() {
        XCTAssertEqual(PixelProgressBar.filledSegments(percent: 0, total: 12), 0)
        XCTAssertEqual(PixelProgressBar.filledSegments(percent: 50, total: 12), 6)
        XCTAssertEqual(PixelProgressBar.filledSegments(percent: 100, total: 12), 12)
        XCTAssertEqual(PixelProgressBar.filledSegments(percent: 120, total: 12), 12) // clamped
        XCTAssertEqual(PixelProgressBar.filledSegments(percent: -5, total: 12), 0)   // clamped
        XCTAssertEqual(PixelProgressBar.filledSegments(percent: 4, total: 12), 1)    // >0 shows at least 1
    }

    func testKindLabels() {
        XCTAssertEqual(LimitRowView.kindLabel(.session), "SESSION")
        XCTAssertEqual(LimitRowView.kindLabel(.weeklyAll), "WEEKLY ALL")
        XCTAssertEqual(LimitRowView.kindLabel(.weeklyModel("Fable")), "WEEKLY FABLE")
    }

    func testResetLabels() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let session = QuotaLimit(kind: .session, percentUsed: 10,
                                 resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60), isActive: false)
        XCTAssertEqual(LimitRowView.resetLabel(for: session, now: now), "RESET 2H 14M")

        let weekly = QuotaLimit(kind: .weeklyAll, percentUsed: 58,
                                resetsAt: Date(timeIntervalSince1970: 1_784_235_600), isActive: true)
        XCTAssertTrue(LimitRowView.resetLabel(for: weekly, now: now).hasPrefix("RESET "))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter UIComponentLogicTests`
Expected: FAIL — `cannot find 'PixelProgressBar' in scope`.

- [ ] **Step 3: Implement the components**

`Sources/AILimitBarKit/UI/Retro/PixelProgressBar.swift`:
```swift
import SwiftUI

public struct PixelProgressBar: View {
    let percent: Double
    let palette: RetroPalette
    static let totalSegments = 12

    public init(percent: Double, palette: RetroPalette) {
        self.percent = percent
        self.palette = palette
    }

    public static func filledSegments(percent: Double, total: Int) -> Int {
        let clamped = min(max(percent, 0), 100)
        if clamped == 0 { return 0 }
        return max(1, Int((clamped / 100 * Double(total)).rounded()))
    }

    public var body: some View {
        let filled = Self.filledSegments(percent: percent, total: Self.totalSegments)
        let color = RetroTheme.color(for: Severity(percent: percent), in: palette)
        HStack(spacing: 2) {
            ForEach(0..<Self.totalSegments, id: \.self) { i in
                Rectangle()
                    .fill(i < filled ? color : palette.surface)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(2)
        .overlay(Rectangle().stroke(palette.textPrimary.opacity(0.4), lineWidth: 1))
        .accessibilityLabel("\(Int(percent)) percent used")
    }
}
```

`Sources/AILimitBarKit/UI/Retro/AvatarSpriteView.swift`:
```swift
import SwiftUI

public struct AvatarSpriteView: View {
    let sprite: Sprite
    let color: Color
    let pixelScale: CGFloat

    public init(sprite: Sprite, color: Color, pixelScale: CGFloat = 2) {
        self.sprite = sprite
        self.color = color
        self.pixelScale = pixelScale
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.3)
            let frame = sprite.frames[tick % sprite.frames.count]
            Canvas { ctx, _ in
                for (y, row) in frame.bitmap.enumerated() {
                    for (x, filled) in row.enumerated() where filled {
                        ctx.fill(Path(CGRect(x: CGFloat(x) * pixelScale,
                                             y: CGFloat(y) * pixelScale,
                                             width: pixelScale, height: pixelScale)),
                                 with: .color(color))
                    }
                }
            }
            .frame(width: 16 * pixelScale, height: 16 * pixelScale)
        }
        .accessibilityHidden(true)
    }
}
```

`Sources/AILimitBarKit/UI/Popover/LimitRowView.swift`:
```swift
import SwiftUI

public struct LimitRowView: View {
    let limit: QuotaLimit
    let palette: RetroPalette
    let compact: Bool
    let now: Date

    public init(limit: QuotaLimit, palette: RetroPalette, compact: Bool, now: Date = Date()) {
        self.limit = limit
        self.palette = palette
        self.compact = compact
        self.now = now
    }

    public static func kindLabel(_ kind: LimitKind) -> String {
        switch kind {
        case .session: return "SESSION"
        case .weeklyAll: return "WEEKLY ALL"
        case .weeklyModel(let name): return "WEEKLY \(name.uppercased())"
        }
    }

    public static func resetLabel(for limit: QuotaLimit, now: Date) -> String {
        switch limit.kind {
        case .session:
            return "RESET " + ResetFormatter.sessionCountdown(until: limit.resetsAt, from: now)
        case .weeklyAll, .weeklyModel:
            return "RESET " + ResetFormatter.weeklyReset(limit.resetsAt)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Self.kindLabel(limit.kind))
                    .font(PixelFont.swiftUI(size: 8))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(Int(limit.percentUsed))%")
                    .font(PixelFont.swiftUI(size: 8))
                    .foregroundStyle(RetroTheme.color(for: Severity(percent: limit.percentUsed), in: palette))
                if limit.isActive {
                    Text("◀")
                        .font(.system(size: 8))
                        .foregroundStyle(palette.accentPink)
                        .help("Currently binding limit")
                }
            }
            PixelProgressBar(percent: limit.percentUsed, palette: palette)
            if !compact {
                Text(Self.resetLabel(for: limit, now: now))
                    .font(PixelFont.swiftUI(size: 6))
                    .foregroundStyle(palette.textPrimary.opacity(0.7))
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter UIComponentLogicTests && swift build`
Expected: PASS (3 tests) and clean build.

- [ ] **Step 5: Commit**

```bash
git add Sources/AILimitBarKit/UI Tests/AILimitBarKitTests/UIComponentLogicTests.swift
git commit -m "feat: pixel progress bar, animated avatar view, limit row"
```

---

### Task 14: Popover + Settings views

**Files:**
- Create: `Sources/AILimitBarKit/UI/Popover/QuotaPopoverView.swift`
- Create: `Sources/AILimitBarKit/UI/Settings/SettingsView.swift`
- Test: `Tests/AILimitBarKitTests/PopoverLogicTests.swift`

**Interfaces:**
- Consumes: `QuotaStore`, `AppSettings`, `L10n`, `RetroTheme`, `LimitRowView`, `AvatarSpriteView`, `SpriteLibrary` (Tasks 8-13).
- Produces:
  - `struct QuotaPopoverView: View { init(store: QuotaStore, settings: AppSettings, onOpenSettings: @escaping () -> Void) }` — renders all five states; filters limits via `settings.isVisible`.
  - `struct SettingsView: View { init(settings: AppSettings) }` — General/Display/Avatar panes.
  - `QuotaPopoverView.visibleLimits(_ snapshot: QuotaSnapshot?, settings: AppSettings) -> [QuotaLimit]` (static, testable).

- [ ] **Step 1: Write the failing test**

`Tests/AILimitBarKitTests/PopoverLogicTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

@MainActor
final class PopoverLogicTests: XCTestCase {
    func testVisibleLimitsFiltering() {
        let snapshot = QuotaSnapshot(planName: "CLAUDE MAX", limits: [
            QuotaLimit(kind: .session, percentUsed: 10, resetsAt: Date(), isActive: false),
            QuotaLimit(kind: .weeklyAll, percentUsed: 58, resetsAt: Date(), isActive: true),
            QuotaLimit(kind: .weeklyModel("Fable"), percentUsed: 38, resetsAt: Date(), isActive: false),
        ], fetchedAt: Date())

        let defaults = UserDefaults(suiteName: "PopoverLogicTests")!
        defaults.removePersistentDomain(forName: "PopoverLogicTests")
        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(QuotaPopoverView.visibleLimits(snapshot, settings: settings).count, 3)
        settings.showWeeklyModels = false
        XCTAssertEqual(QuotaPopoverView.visibleLimits(snapshot, settings: settings).count, 2)
        settings.showSession = false
        XCTAssertEqual(QuotaPopoverView.visibleLimits(snapshot, settings: settings).map(\.kind), [.weeklyAll])
        XCTAssertEqual(QuotaPopoverView.visibleLimits(nil, settings: settings), [])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PopoverLogicTests`
Expected: FAIL — `cannot find 'QuotaPopoverView' in scope`.

- [ ] **Step 3: Implement the popover view**

`Sources/AILimitBarKit/UI/Popover/QuotaPopoverView.swift`:
```swift
import SwiftUI

public struct QuotaPopoverView: View {
    @Environment(\.colorScheme) private var colorScheme
    let store: QuotaStore
    let settings: AppSettings
    let onOpenSettings: () -> Void

    public init(store: QuotaStore, settings: AppSettings, onOpenSettings: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.onOpenSettings = onOpenSettings
    }

    public static func visibleLimits(_ snapshot: QuotaSnapshot?, settings: AppSettings) -> [QuotaLimit] {
        (snapshot?.limits ?? []).filter { settings.isVisible($0.kind) }
    }

    private var palette: RetroPalette {
        RetroTheme.palette(settings.theme, systemIsDark: colorScheme == .dark)
    }

    public var body: some View {
        let palette = self.palette
        VStack(alignment: .leading, spacing: 10) {
            header(palette)
            content(palette)
            footer(palette)
        }
        .padding(14)
        .frame(width: 240)
        .background(palette.background)
    }

    @ViewBuilder
    private func header(_ palette: RetroPalette) -> some View {
        HStack {
            Text(store.currentSnapshot?.planName ?? "AI QUOTA")
                .font(PixelFont.swiftUI(size: 9))
                .foregroundStyle(palette.accentCyan)
            Spacer()
            AvatarSpriteView(
                sprite: SpriteLibrary.sprite(for: settings.avatar),
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
    private func content(_ palette: RetroPalette) -> some View {
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
                Text("\(L10n.t(.offlineLastUpdated, settings.language)): \(last.fetchedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(palette.textPrimary.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    private func footer(_ palette: RetroPalette) -> some View {
        Button(action: onOpenSettings) {
            Text("⚙ SETTINGS")
                .font(PixelFont.swiftUI(size: 7))
                .foregroundStyle(palette.textPrimary.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 4: Implement the settings view**

`Sources/AILimitBarKit/UI/Settings/SettingsView.swift`:
```swift
import SwiftUI

public struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
    }

    private var palette: RetroPalette {
        RetroTheme.palette(settings.theme, systemIsDark: colorScheme == .dark)
    }

    private func t(_ key: L10nKey) -> String { L10n.t(key, settings.language) }

    public var body: some View {
        let palette = self.palette
        VStack(alignment: .leading, spacing: 16) {
            section(t(.settingsGeneral), palette) {
                Picker(t(.settingsLanguage), selection: $settings.language) {
                    Text("English").tag(AppLanguage.en)
                    Text("ไทย").tag(AppLanguage.th)
                }
                Picker(t(.settingsTheme), selection: $settings.theme) {
                    Text(t(.themeSystem)).tag(ThemePreference.system)
                    Text(t(.themeDark)).tag(ThemePreference.dark)
                    Text(t(.themeLight)).tag(ThemePreference.light)
                }
            }
            section(t(.settingsDisplay), palette) {
                Toggle(t(.showPercent), isOn: $settings.showPercentInMenuBar)
                Picker(t(.headlinePinLabel), selection: $settings.headlinePin) {
                    Text(t(.pinAuto)).tag(HeadlinePin.auto)
                    Text(t(.pinSession)).tag(HeadlinePin.session)
                    Text(t(.pinWeekly)).tag(HeadlinePin.weekly)
                }
                Text(t(.visibleLimits))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(palette.textPrimary.opacity(0.6))
                Toggle(t(.limitSession), isOn: $settings.showSession)
                Toggle(t(.limitWeeklyAll), isOn: $settings.showWeeklyAll)
                Toggle(t(.limitWeeklyModels), isOn: $settings.showWeeklyModels)
                Toggle(t(.compactRows), isOn: $settings.compactRows)
            }
            section(t(.settingsAvatar), palette) {
                Text(t(.chooseAvatar))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(palette.textPrimary.opacity(0.6))
                HStack(spacing: 16) {
                    ForEach(AvatarID.allCases, id: \.self) { id in
                        avatarButton(id, palette)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(palette.background)
        .foregroundStyle(palette.textPrimary)
        .tint(palette.accentCyan)
    }

    @ViewBuilder
    private func section(_ title: String, _ palette: RetroPalette,
                         @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(PixelFont.swiftUI(size: 8))
                .foregroundStyle(palette.accentPink)
            content()
        }
    }

    @ViewBuilder
    private func avatarButton(_ id: AvatarID, _ palette: RetroPalette) -> some View {
        Button {
            settings.avatar = id
        } label: {
            VStack(spacing: 4) {
                AvatarSpriteView(sprite: SpriteLibrary.sprite(for: id),
                                 color: palette.ok, pixelScale: 2)
                Text(id.rawValue.uppercased())
                    .font(PixelFont.swiftUI(size: 6))
            }
            .padding(6)
            .overlay(Rectangle().stroke(
                settings.avatar == id ? palette.accentCyan : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 5: Run tests + build**

Run: `swift test --filter PopoverLogicTests && swift build`
Expected: PASS (1 test), clean build.

- [ ] **Step 6: Commit**

```bash
git add Sources/AILimitBarKit/UI Tests/AILimitBarKitTests/PopoverLogicTests.swift
git commit -m "feat: retro popover and settings views"
```

---

### Task 15: App shell — StatusItemController, AppDelegate, main

**Files:**
- Create: `Sources/AILimitBarKit/App/StatusItemController.swift`
- Create: `Sources/AILimitBarKit/App/AppDelegate.swift`
- Create: `Sources/AILimitBarKit/App/SettingsWindowController.swift`
- Modify: `Sources/AILimitBar/main.swift`
- Delete: `Sources/AILimitBarKit/Core/Placeholder.swift`
- Test: `Tests/AILimitBarKitTests/StatusItemLogicTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 8-14.
- Produces:
  - `@MainActor final class StatusItemController { init(store: QuotaStore, settings: AppSettings); func start() }` — owns `NSStatusItem` + `NSPopover`, 1 s UI tick.
  - `static func menuBarTitle(headline: QuotaLimit?, state: QuotaStore.State, showPercent: Bool) -> String` — `"42%"`, `""` (hidden), `"--"` (error states).
  - `static func menuBarColor(headline: QuotaLimit?, state: QuotaStore.State, palette: RetroPalette) -> NSColor` — severity color, gray (`NSColor.systemGray`) for error states.
  - `public final class AppDelegate: NSObject, NSApplicationDelegate` — wires settings/provider/store/controller, registers font, starts polling.

- [ ] **Step 1: Write the failing test**

`Tests/AILimitBarKitTests/StatusItemLogicTests.swift`:
```swift
import XCTest
@testable import AILimitBarKit

@MainActor
final class StatusItemLogicTests: XCTestCase {
    private let headline = QuotaLimit(kind: .weeklyAll, percentUsed: 58,
                                      resetsAt: Date(), isActive: true)
    private let snap = QuotaSnapshot(planName: "CLAUDE MAX", limits: [], fetchedAt: Date())

    func testTitle() {
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: headline, state: .ready(snap), showPercent: true), "58%")
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: headline, state: .ready(snap), showPercent: false), "")
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: nil, state: .tokenExpired, showPercent: true), "--")
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: nil, state: .credentialsMissing, showPercent: true), "--")
        // Offline with stale data still shows the stale number.
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: headline, state: .offline(last: snap), showPercent: true), "58%")
    }

    func testColor() {
        let palette = RetroTheme.dark
        // NSColor(Color) equality is unreliable — compare sRGB components instead.
        let ready = StatusItemController.menuBarColor(
            headline: headline, state: .ready(snap), palette: palette)
            .usingColorSpace(.sRGB)!
        let expected = NSColor(palette.ok).usingColorSpace(.sRGB)!
        XCTAssertEqual(ready.redComponent, expected.redComponent, accuracy: 0.01)
        XCTAssertEqual(ready.greenComponent, expected.greenComponent, accuracy: 0.01)
        XCTAssertEqual(ready.blueComponent, expected.blueComponent, accuracy: 0.01)
        XCTAssertEqual(StatusItemController.menuBarColor(
            headline: nil, state: .tokenExpired, palette: palette), .systemGray)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter StatusItemLogicTests`
Expected: FAIL — `cannot find 'StatusItemController' in scope`.

- [ ] **Step 3: Implement StatusItemController**

`Sources/AILimitBarKit/App/StatusItemController.swift`:
```swift
import AppKit
import SwiftUI

@MainActor
public final class StatusItemController {
    private let store: QuotaStore
    private let settings: AppSettings
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var tickTimer: Timer?
    private var frameIndex = 0
    private lazy var settingsWindow = SettingsWindowController(settings: settings)

    public init(store: QuotaStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
    }

    public func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: QuotaPopoverView(store: store, settings: settings) { [weak self] in
                self?.popover?.performClose(nil)
                self?.settingsWindow.show()
            })
        self.popover = popover

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    private func tick() {
        // Pause the idle animation in Low Power Mode (still updates numbers).
        if !ProcessInfo.processInfo.isLowPowerModeEnabled {
            frameIndex += 1
        }
        render()
    }

    private var systemIsDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func render() {
        guard let button = statusItem?.button else { return }
        let palette = RetroTheme.palette(settings.theme, systemIsDark: systemIsDark)
        let headline = store.headlineLimit(pin: settings.headlinePin)
        let color = Self.menuBarColor(headline: headline, state: store.state, palette: palette)
        let sprite = SpriteLibrary.sprite(for: settings.avatar)
        let frames = sprite.menuBarFrames
        button.image = frames[frameIndex % frames.count].nsImage(color: color, pixelSize: 1.1)
        button.image?.isTemplate = false

        let title = Self.menuBarTitle(headline: headline, state: store.state,
                                      showPercent: settings.showPercentInMenuBar)
        button.attributedTitle = NSAttributedString(
            string: title.isEmpty ? "" : " " + title,
            attributes: [
                .font: PixelFont.nsFont(size: 9),
                .foregroundColor: color,
                .baselineOffset: 1,
            ])
    }

    public static func menuBarTitle(headline: QuotaLimit?, state: QuotaStore.State,
                                    showPercent: Bool) -> String {
        switch state {
        case .credentialsMissing, .tokenExpired, .loading:
            return "--"
        case .ready, .offline:
            guard showPercent else { return "" }
            guard let headline else { return "--" }
            return "\(Int(headline.percentUsed))%"
        }
    }

    public static func menuBarColor(headline: QuotaLimit?, state: QuotaStore.State,
                                    palette: RetroPalette) -> NSColor {
        switch state {
        case .credentialsMissing, .tokenExpired, .loading:
            return .systemGray
        case .ready, .offline:
            guard let headline else { return .systemGray }
            return NSColor(RetroTheme.color(for: Severity(percent: headline.percentUsed),
                                            in: palette))
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            Task { await store.refreshIfStale(olderThan: 10) }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
```

- [ ] **Step 4: Implement SettingsWindowController and AppDelegate**

`Sources/AILimitBarKit/App/SettingsWindowController.swift`:
```swift
import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let settings: AppSettings
    private var window: NSWindow?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: settings))
            let window = NSWindow(contentViewController: hosting)
            window.title = "AI LIMIT BAR"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

`Sources/AILimitBarKit/App/AppDelegate.swift`:
```swift
import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?
    private var store: QuotaStore?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        PixelFont.registerBundledFont()
        let settings = AppSettings()
        let store = QuotaStore(provider: ClaudeProvider())
        let controller = StatusItemController(store: store, settings: settings)
        self.store = store
        self.controller = controller
        controller.start()
        store.startPolling(interval: 60)
    }
}
```

Replace `Sources/AILimitBar/main.swift` with:
```swift
import AppKit
import AILimitBarKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

Delete `Sources/AILimitBarKit/Core/Placeholder.swift` and remove the `testVersion` assertion file `Tests/AILimitBarKitTests/ScaffoldTests.swift`.

- [ ] **Step 5: Run all tests + build**

Run: `swift test && swift build`
Expected: all tests PASS, clean build.

- [ ] **Step 6: Quick live run**

Run: `swift run AILimitBar &` then check the menu bar. Expected: pixel avatar + percentage appears; click opens the popover with real quota; kill with `kill %1`. (A Keychain "Allow" prompt may appear on first run.)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: app shell — status item, popover wiring, settings window"
```

---

### Task 16: Packaging, docs, CI

**Files:**
- Create: `Scripts/bundle.sh`
- Create: `Scripts/Info.plist`
- Create: `LICENSE`
- Create: `README.md`
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: the built `AILimitBar` executable and the `ai-limit-bar_AILimitBarKit.bundle` resource bundle produced by `swift build -c release`.
- Produces: `AILimitBar.app` (ad-hoc signed, `LSUIElement=true`), MIT license, README with security section, CI workflow.

- [ ] **Step 1: Create Scripts/Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AI Limit Bar</string>
    <key>CFBundleDisplayName</key><string>AI Limit Bar</string>
    <key>CFBundleIdentifier</key><string>dev.ailimitbar.app</string>
    <key>CFBundleVersion</key><string>0.1.0</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleExecutable</key><string>AILimitBar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
```

- [ ] **Step 2: Create Scripts/bundle.sh**

```bash
#!/bin/bash
# Builds AILimitBar.app from the SwiftPM release build.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="AILimitBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp Scripts/Info.plist "$APP/Contents/Info.plist"
cp .build/release/AILimitBar "$APP/Contents/MacOS/AILimitBar"
# SwiftPM resource bundle (pixel font) must sit next to Resources for Bundle.module.
cp -R .build/release/ai-limit-bar_AILimitBarKit.bundle "$APP/Contents/Resources/"

codesign --force --deep --sign - "$APP"
echo "Built $APP (ad-hoc signed)"
```

Run: `chmod +x Scripts/bundle.sh && ./Scripts/bundle.sh`
Expected: `Built AILimitBar.app (ad-hoc signed)`. If the `.bundle` copy fails, list `.build/release/*.bundle` and use the actual name.

- [ ] **Step 3: Verify the bundle launches with resources**

Run: `open AILimitBar.app` — menu bar shows the pixel avatar in the **pixel font** (font loads from the bundle, proving `Bundle.module` resolution works inside the .app). Open popover, open settings, then quit via Activity Monitor or `pkill AILimitBar`.
Expected: quota renders; popover title uses Press Start 2P (blocky letters), not a fallback font.

- [ ] **Step 4: Create LICENSE (MIT) and README.md**

`LICENSE`: standard MIT text with `Copyright (c) 2026 ai-limit-bar contributors`.

`README.md`:
```markdown
# ai-limit-bar

A retro 8-bit menu bar app for macOS that shows your Claude Pro/Max
subscription quota — session (5-hour), weekly, and per-model limits with
used %, HP-style pixel bars, and reset times.

![screenshot placeholder — add after first release]

## Requirements

- macOS 14+
- [Claude Code](https://claude.com/claude-code) installed and signed in
  (this app reads the quota through Claude Code's credentials)

## Install

Download `AILimitBar.app` from Releases. The app is not notarized yet:
right-click → Open on first launch (or `xattr -d com.apple.quarantine AILimitBar.app`).

Or build from source: `./Scripts/bundle.sh` (needs Xcode 15+ command line tools).

## Security

- **Read-only.** The app reads Claude Code's OAuth access token from the
  macOS Keychain (item "Claude Code-credentials"; you'll see a one-time
  "Allow" dialog) with a fallback to `~/.claude/.credentials.json`.
  It never writes to either store and never refreshes tokens.
- The token stays in memory, is never logged, and is sent to exactly one
  place: `https://api.anthropic.com/api/oauth/usage` over HTTPS.
- No telemetry, no analytics, no auto-update pings.
- Note: the usage endpoint is the same one Claude Code's `/usage` command
  uses; it is not officially documented and may change.

## Settings

Language EN/ไทย · theme Dark/Light/System · show/hide menu bar % · pick which
limit the % tracks · choose visible limits · compact rows · three animated
pixel avatars (BOO / BUG / BOT).

## License

MIT. Press Start 2P font © CodeMan38, SIL Open Font License 1.1.
```

- [ ] **Step 5: Create .github/workflows/ci.yml**

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: swift build
      - name: Test
        run: swift test
      - name: Bundle
        run: ./Scripts/bundle.sh
```

- [ ] **Step 6: Final full verification**

Run: `swift test && ./Scripts/bundle.sh`
Expected: all tests PASS; bundle builds.

Manual smoke checklist (run `open AILimitBar.app`, then walk through):
- [ ] Menu bar: avatar animates (2 frames), % shows, color matches usage level
- [ ] Popover: all limits with bars, %, reset lines; ◀ on the active limit
- [ ] Settings → theme Dark and Light both render retro palettes; System follows macOS
- [ ] Settings → ภาษาไทย: prose becomes Thai, game labels stay EN pixel font
- [ ] Settings → each show/hide toggle affects menu bar/popover immediately
- [ ] Settings → switching avatar changes both menu bar and popover sprite
- [ ] Compact rows hides reset lines
- [ ] Error state: temporarily rename `~/.claude/.credentials.json` AND relaunch with Keychain denied → INSERT COIN screen (restore afterwards!)
- [ ] Offline: turn Wi-Fi off → OFFLINE badge with stale data; Wi-Fi on → recovers

- [ ] **Step 7: Commit**

```bash
git add Scripts LICENSE README.md .github
git commit -m "chore: app bundling, MIT license, README, CI"
```

---

## Self-Review Notes

- **Spec coverage:** models/severity (T2), date+decoding of the verified endpoint (T3-4), formatter (T5), keychain-first read-only credentials (T6), client+provider with local-expiry short-circuit (T7), store with 60 s poll / 10 s stale / backoff / headline (T8), settings incl. all four show/hide options (T9), EN/TH with runtime switch and EN game labels (T10), palettes+font (T11), three original animated sprites (T12), HP bar/rows (T13), popover states INSERT COIN / TOKEN EXPIRED / OFFLINE / LOADING + settings panes (T14), status item title/color rules + Low Power pause (T15), bundle/README-security/MIT/CI + manual smoke checklist (T16).
- Deviation from spec noted: logic lives in `AILimitBarKit` library (thin `AILimitBar` executable) so `swift test` can import it; `QuotaSnapshot` gained `planName`; L10n is a hand-rolled table instead of a String Catalog because the in-app language toggle must switch at runtime. All three recorded here deliberately.
- Launch-at-login, notifications, Sparkle, notarization, Gemini: intentionally absent (spec non-goals).
