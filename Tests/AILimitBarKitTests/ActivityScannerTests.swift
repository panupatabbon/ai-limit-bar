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
