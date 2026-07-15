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
        XCTAssertEqual(summary.skillEventCount, 4) // alpha ×3 + beta ×1
        XCTAssertEqual(summary.agentEventCount, 3) // general-purpose ×2 + reviewer ×1
    }

    func testPercentShare() {
        XCTAssertEqual(ActivitySummary.percentShare(3, of: 4), 75)
        XCTAssertEqual(ActivitySummary.percentShare(1, of: 3), 33)
        XCTAssertEqual(ActivitySummary.percentShare(2, of: 3), 67)
        XCTAssertEqual(ActivitySummary.percentShare(0, of: 10), 0)
        XCTAssertEqual(ActivitySummary.percentShare(5, of: 0), 0)   // no events
        XCTAssertEqual(ActivitySummary.percentShare(1, of: 1000), 1) // never rounds to 0
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

    func testScanSkipsFilesOverSizeCap() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("activity-sizecap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Over the (tiny, test-injected) cap: skipped entirely.
        let big = dir.appendingPathComponent("big.jsonl")
        try #"{"name":"Skill","input":{"skill":"toobig"}}"#.write(
            to: big, atomically: true, encoding: .utf8)

        // Under the cap: still counted.
        let small = dir.appendingPathComponent("small.jsonl")
        try #"{}"#.write(to: small, atomically: true, encoding: .utf8)

        let summary = ActivityScanner(root: dir, maxFileBytes: 10).scan()
        XCTAssertEqual(summary.sessionCount, 1)
        XCTAssertTrue(summary.topSkills.isEmpty)
    }

    func testTop3TruncatesAndBreaksTiesByNameAscending() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("activity-top3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let file = dir.appendingPathComponent("skills.jsonl")
        try [
            #"{"name":"Skill","input":{"skill":"zeta"}}"#,
            #"{"name":"Skill","input":{"skill":"zeta"}}"#,
            #"{"name":"Skill","input":{"skill":"alpha"}}"#,
            #"{"name":"Skill","input":{"skill":"beta"}}"#,
            #"{"name":"Skill","input":{"skill":"gamma"}}"#,
        ].joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)

        let summary = ActivityScanner(root: dir).scan()
        // zeta:2, then alpha/beta/gamma tied at 1 -> name-ascending picks alpha, beta.
        XCTAssertEqual(summary.topSkills, [
            ActivityCount(name: "zeta", count: 2),
            ActivityCount(name: "alpha", count: 1),
            ActivityCount(name: "beta", count: 1),
        ])
    }
}
