import Foundation

/// Read-only, best-effort scan of Claude Code transcripts for the last-24h
/// activity section. String-search based (the JSONL format is undocumented);
/// malformed input is skipped, never fatal. File contents are never logged.
public struct ActivityScanner: Sendable {
    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    /// Files larger than this are skipped rather than read whole into memory:
    /// other users' transcripts can be tens-to-hundreds of MB, and a full
    /// String read every 5-minute scan risks a memory spike.
    public static let maxFileBytes = 64 * 1024 * 1024

    let root: URL
    let window: TimeInterval
    let now: @Sendable () -> Date
    let maxFileBytes: Int

    public init(root: URL = ActivityScanner.defaultRoot,
                window: TimeInterval = 86_400,
                now: @escaping @Sendable () -> Date = { Date() },
                maxFileBytes: Int = ActivityScanner.maxFileBytes) {
        self.root = root
        self.window = window
        self.now = now
        self.maxFileBytes = maxFileBytes
    }

    public func scan() -> ActivitySummary {
        let cutoff = now().addingTimeInterval(-window)
        var skills: [String: Int] = [:]
        var agents: [String: Int] = [:]
        var sessions = 0

        let files = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles])

        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "jsonl",
                  let resourceValues = try? url.resourceValues(
                      forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modified = resourceValues.contentModificationDate,
                  modified >= cutoff,
                  let fileSize = resourceValues.fileSize,
                  fileSize <= maxFileBytes,
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
            skillEventCount: skills.values.reduce(0, +),
            agentEventCount: agents.values.reduce(0, +),
            sessionCount: sessions, scannedAt: now())
    }

    private func top3(_ counts: [String: Int]) -> [ActivityCount] {
        counts.map { ActivityCount(name: $0.key, count: $0.value) }
            // Sort by count descending, then name ascending (the swapped-tuple trick:
            // comparing ($0.count, $1.name) > ($1.count, $0.name) flips the name order).
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
