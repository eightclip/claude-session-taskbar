import Foundation
import Combine
import Cocoa
import Security

// MARK: - Configuration
struct TaskbarConfig: Codable {
    var refreshIntervalSeconds: Int

    static let `default` = TaskbarConfig(
        refreshIntervalSeconds: 60
    )

    static var configPath: String {
        NSString(string: "~/.claude-taskbar.json").expandingTildeInPath
    }
}

// MARK: - Usage Tracker
class UsageTracker: ObservableObject {
    // Published API data
    @Published var sessionPercentage: Double = 0
    @Published var weeklyPercentage: Double = 0
    @Published var sessionResetDate: Date?
    @Published var weeklyResetDate: Date?
    @Published var sessionStatus: String = "unknown"
    @Published var weeklyStatus: String = "unknown"

    // Published meta
    @Published var lastUpdated: Date = Date()
    @Published var hasData: Bool = false
    @Published var isAPIMode: Bool = false
    @Published var errorMessage: String?

    // Config
    var config: TaskbarConfig = .default

    // Internal
    private var cachedToken: String?

    // MARK: - Initialization
    init() {
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

    // MARK: - OAuth Token Retrieval

    /// Read OAuth token from macOS Keychain (where Claude Code stores it)
    private func getTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Parse JSON: {"claudeAiOauth":{"accessToken":"sk-ant-oat01-..."}}
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }

        return token
    }

    /// Get OAuth token from env var (when launched from Claude Code)
    private func getTokenFromEnv() -> String? {
        let token = ProcessInfo.processInfo.environment["CLAUDE_CODE_OAUTH_TOKEN"]
        if let t = token, !t.isEmpty { return t }
        return nil
    }

    /// Get token with caching — tries Keychain first, then env var
    private func getToken() -> String? {
        if let cached = cachedToken { return cached }

        if let token = getTokenFromKeychain() {
            cachedToken = token
            return token
        }

        if let token = getTokenFromEnv() {
            cachedToken = token
            return token
        }

        return nil
    }

    // MARK: - API-Based Refresh
    func refresh() {
        loadConfig()

        guard let token = getToken() else {
            DispatchQueue.main.async {
                self.isAPIMode = false
                self.hasData = false
                self.errorMessage = "No Claude Code credentials found in Keychain"
            }
            return
        }

        fetchUsageFromAPI(token: token)
    }

    private func fetchUsageFromAPI(token: String) {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        // Minimal request — cheapest possible (Haiku, 1 token)
        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "x"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "API error: \(error.localizedDescription)"
                    self.hasData = false
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.errorMessage = "Invalid API response"
                    self.hasData = false
                }
                return
            }

            // Check for auth errors
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                DispatchQueue.main.async {
                    self.cachedToken = nil // Force re-read on next refresh
                    self.errorMessage = "Token expired — restart Claude Code"
                    self.isAPIMode = false
                    self.hasData = false
                }
                return
            }

            // Parse rate limit headers
            let headers = httpResponse.allHeaderFields

            let sessionUtil = self.parseDoubleHeader(headers, key: "anthropic-ratelimit-unified-5h-utilization")
            let weeklyUtil = self.parseDoubleHeader(headers, key: "anthropic-ratelimit-unified-7d-utilization")
            let sessionReset = self.parseTimestampHeader(headers, key: "anthropic-ratelimit-unified-5h-reset")
            let weeklyReset = self.parseTimestampHeader(headers, key: "anthropic-ratelimit-unified-7d-reset")
            let sessionStat = self.parseStringHeader(headers, key: "anthropic-ratelimit-unified-5h-status")
            let weeklyStat = self.parseStringHeader(headers, key: "anthropic-ratelimit-unified-7d-status")

            DispatchQueue.main.async {
                self.sessionPercentage = sessionUtil ?? 0
                self.weeklyPercentage = weeklyUtil ?? 0
                self.sessionResetDate = sessionReset
                self.weeklyResetDate = weeklyReset
                self.sessionStatus = sessionStat ?? "unknown"
                self.weeklyStatus = weeklyStat ?? "unknown"
                self.isAPIMode = true
                self.hasData = true
                self.errorMessage = nil
                self.lastUpdated = Date()
            }
        }
        task.resume()
    }

    // MARK: - Header Parsing
    private func parseDoubleHeader(_ headers: [AnyHashable: Any], key: String) -> Double? {
        // Case-insensitive header lookup
        for (k, v) in headers {
            if let headerKey = k as? String, headerKey.lowercased() == key.lowercased() {
                if let str = v as? String { return Double(str) }
                if let num = v as? Double { return num }
            }
        }
        return nil
    }

    private func parseTimestampHeader(_ headers: [AnyHashable: Any], key: String) -> Date? {
        for (k, v) in headers {
            if let headerKey = k as? String, headerKey.lowercased() == key.lowercased() {
                if let str = v as? String, let ts = TimeInterval(str) {
                    return Date(timeIntervalSince1970: ts)
                }
            }
        }
        return nil
    }

    private func parseStringHeader(_ headers: [AnyHashable: Any], key: String) -> String? {
        for (k, v) in headers {
            if let headerKey = k as? String, headerKey.lowercased() == key.lowercased() {
                return v as? String
            }
        }
        return nil
    }

    // MARK: - Display Helpers
    var sessionDetail: String {
        guard let reset = sessionResetDate else { return "No data" }
        return "Resets \(Theme.formatCountdown(to: reset))"
    }

    var weeklyDetail: String {
        guard let reset = weeklyResetDate else { return "No data" }
        return "Resets \(Theme.formatCountdown(to: reset))"
    }

    var lastUpdatedText: String {
        Theme.formatTimeAgo(lastUpdated)
    }
}
