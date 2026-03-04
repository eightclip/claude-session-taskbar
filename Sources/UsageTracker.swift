import Foundation
import Combine
import Cocoa

// MARK: - Configuration
struct TaskbarConfig: Codable {
    var sessionTokenLimit: Int
    var weeklyTokenLimit: Int
    var refreshIntervalSeconds: Int

    static let `default` = TaskbarConfig(
        sessionTokenLimit: 5_000_000,
        weeklyTokenLimit: 45_000_000,
        refreshIntervalSeconds: 10
    )

    static var configPath: String {
        NSString(string: "~/.claude-taskbar.json").expandingTildeInPath
    }
}

// MARK: - Token Data
struct TokenData {
    var input: Int = 0
    var output: Int = 0
    var cacheCreate: Int = 0
    var cacheRead: Int = 0
    var apiCalls: Int = 0

    // Billable tokens only — cache reads are nearly free and inflate the total
    var total: Int { input + output + cacheCreate }

    mutating func add(_ other: TokenData) {
        input       += other.input
        output      += other.output
        cacheCreate += other.cacheCreate
        cacheRead   += other.cacheRead
        apiCalls    += other.apiCalls
    }
}

// MARK: - File Tracking State
private struct FileState {
    var offset: UInt64 = 0
    var data: TokenData = TokenData()
    var modDate: Date = .distantPast
    var fileSize: UInt64 = 0
}

// MARK: - Session Info
struct SessionInfo {
    var filePath: String
    var tokens: TokenData
    var modDate: Date
    var projectDir: String
}

// MARK: - Usage Tracker
class UsageTracker: ObservableObject {
    // Published session data
    @Published var sessionTokens: Int = 0
    @Published var sessionOutputTokens: Int = 0
    @Published var sessionApiCalls: Int = 0
    @Published var sessionStartTime: Date?
    @Published var currentSessionId: String = ""

    // Published weekly data
    @Published var weeklyTokens: Int = 0
    @Published var weeklyOutputTokens: Int = 0
    @Published var weeklyApiCalls: Int = 0
    @Published var weeklySessions: Int = 0

    // Published meta
    @Published var lastUpdated: Date = Date()
    @Published var hasData: Bool = false

    // Config
    var config: TaskbarConfig = .default

    // Internal state
    private var fileStates: [String: FileState] = [:]
    private let claudeDir: String

    // MARK: - Computed Properties
    var sessionPercentage: Double {
        guard config.sessionTokenLimit > 0 else { return 0 }
        return Double(sessionTokens) / Double(config.sessionTokenLimit)
    }

    var weeklyPercentage: Double {
        guard config.weeklyTokenLimit > 0 else { return 0 }
        return Double(weeklyTokens) / Double(config.weeklyTokenLimit)
    }

    var sessionDetail: String {
        guard sessionStartTime != nil else { return "No active session" }
        let duration = Theme.formatDuration(from: sessionStartTime!, to: Date())
        return "\(sessionApiCalls) calls \u{00B7} \(duration)"
    }

    var weeklyDetail: String {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let today = dayNames[weekday - 1]
        return "\(weeklySessions) sessions \u{00B7} Through \(today)"
    }

    var lastUpdatedText: String {
        Theme.formatTimeAgo(lastUpdated)
    }

    // MARK: - Initialization
    init() {
        claudeDir = NSString(string: "~/.claude").expandingTildeInPath
        loadConfig()
        refresh()
    }

    // MARK: - Config Management
    func loadConfig() {
        let path = TaskbarConfig.configPath
        if FileManager.default.fileExists(atPath: path) {
            if let data = FileManager.default.contents(atPath: path),
               let loaded = try? JSONDecoder().decode(TaskbarConfig.self, from: data) {
                config = loaded
            }
        } else {
            saveDefaultConfig()
        }
    }

    private func saveDefaultConfig() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(TaskbarConfig.default) {
            FileManager.default.createFile(atPath: TaskbarConfig.configPath, contents: data)
        }
    }

    func openConfig() {
        let path = TaskbarConfig.configPath
        if !FileManager.default.fileExists(atPath: path) {
            saveDefaultConfig()
        }
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: path)],
            withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    // MARK: - Data Refresh
    func refresh() {
        loadConfig()

        let projectsDir = claudeDir + "/projects"
        guard FileManager.default.fileExists(atPath: projectsDir) else {
            hasData = false
            return
        }

        // Find all project directories
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(atPath: projectsDir) else { return }

        var allSessions: [SessionInfo] = []

        for projDir in projectDirs {
            let projPath = projectsDir + "/" + projDir
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: projPath, isDirectory: &isDir), isDir.boolValue else { continue }

            // Find all JSONL files in this project directory
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: projPath) else { continue }
            for file in files where file.hasSuffix(".jsonl") {
                let filePath = projPath + "/" + file
                let tokens = parseFile(at: filePath)
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                      let modDate = attrs[.modificationDate] as? Date else { continue }

                allSessions.append(SessionInfo(
                    filePath: filePath,
                    tokens: tokens,
                    modDate: modDate,
                    projectDir: projDir
                ))
            }
        }

        guard !allSessions.isEmpty else {
            hasData = false
            return
        }

        hasData = true

        // Current session = most recently modified
        let sorted = allSessions.sorted { $0.modDate > $1.modDate }
        if let current = sorted.first {
            sessionTokens = current.tokens.total
            sessionOutputTokens = current.tokens.output
            sessionApiCalls = current.tokens.apiCalls
            currentSessionId = String(URL(fileURLWithPath: current.filePath).deletingPathExtension().lastPathComponent.prefix(8))

            // Estimate session start from file creation
            if let attrs = try? FileManager.default.attributesOfItem(atPath: current.filePath),
               let created = attrs[.creationDate] as? Date {
                sessionStartTime = created
            }
        }

        // Weekly = all sessions from last 7 days
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let weeklySessions = sorted.filter { $0.modDate >= sevenDaysAgo }

        var weeklyTotal = TokenData()
        for session in weeklySessions {
            weeklyTotal.add(session.tokens)
        }

        weeklyTokens = weeklyTotal.total
        weeklyOutputTokens = weeklyTotal.output
        weeklyApiCalls = weeklyTotal.apiCalls
        self.weeklySessions = weeklySessions.count

        lastUpdated = Date()
    }

    // MARK: - File Parsing
    private func parseFile(at path: String) -> TokenData {
        // Check if file has changed since last parse
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modDate = attrs[.modificationDate] as? Date,
              let fileSize = attrs[.size] as? UInt64 else {
            return fileStates[path]?.data ?? TokenData()
        }

        if let existing = fileStates[path] {
            if existing.fileSize == fileSize && existing.modDate == modDate {
                return existing.data // File unchanged, return cached
            }
            // File changed, read from last offset
            return parseFileIncremental(at: path, from: existing)
        }

        // First time reading this file
        return parseFileFull(at: path, fileSize: fileSize, modDate: modDate)
    }

    private func parseFileFull(at path: String, fileSize: UInt64, modDate: Date) -> TokenData {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            return TokenData()
        }
        defer { handle.closeFile() }

        var tokens = TokenData()
        let data = handle.readDataToEndOfFile()
        let newOffset = handle.offsetInFile

        if let text = String(data: data, encoding: .utf8) {
            tokens = extractTokens(from: text)
        }

        fileStates[path] = FileState(
            offset: newOffset,
            data: tokens,
            modDate: modDate,
            fileSize: fileSize
        )

        return tokens
    }

    private func parseFileIncremental(at path: String, from state: FileState) -> TokenData {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            return state.data
        }
        defer { handle.closeFile() }

        handle.seek(toFileOffset: state.offset)
        let newData = handle.readDataToEndOfFile()
        let newOffset = handle.offsetInFile

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modDate = attrs[.modificationDate] as? Date,
              let fileSize = attrs[.size] as? UInt64 else {
            return state.data
        }

        var tokens = state.data
        if let text = String(data: newData, encoding: .utf8) {
            let newTokens = extractTokens(from: text)
            tokens.add(newTokens)
        }

        fileStates[path] = FileState(
            offset: newOffset,
            data: tokens,
            modDate: modDate,
            fileSize: fileSize
        )

        return tokens
    }

    // MARK: - Token Extraction
    private func extractTokens(from text: String) -> TokenData {
        var tokens = TokenData()

        for line in text.components(separatedBy: "\n") {
            // Only process lines that contain output_tokens (complete API responses)
            guard line.contains("\"output_tokens\"") else { continue }

            let input       = extractInt(from: line, key: "\"input_tokens\":")
            let output      = extractInt(from: line, key: "\"output_tokens\":")
            let cacheCreate = extractInt(from: line, key: "\"cache_creation_input_tokens\":")
            let cacheRead   = extractInt(from: line, key: "\"cache_read_input_tokens\":")

            if let out = output, out > 0 {
                tokens.input       += input ?? 0
                tokens.output      += out
                tokens.cacheCreate += cacheCreate ?? 0
                tokens.cacheRead   += cacheRead ?? 0
                tokens.apiCalls    += 1
            }
        }

        return tokens
    }

    private func extractInt(from string: String, key: String) -> Int? {
        guard let keyRange = string.range(of: key) else { return nil }
        let start = keyRange.upperBound
        var end = start
        while end < string.endIndex && string[end].isNumber {
            end = string.index(after: end)
        }
        guard start < end else { return nil }
        return Int(string[start..<end])
    }
}
