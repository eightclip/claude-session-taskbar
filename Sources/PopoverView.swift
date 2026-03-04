import SwiftUI

// MARK: - Main Popover View
struct PopoverView: View {
    @ObservedObject var tracker: UsageTracker

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            sectionDivider

            UsageSection(
                icon: "bolt.fill",
                title: "Current Session",
                tokens: tracker.sessionTokens,
                limit: tracker.config.sessionTokenLimit,
                percentage: tracker.sessionPercentage,
                outputTokens: tracker.sessionOutputTokens,
                detail: tracker.sessionDetail
            )

            sectionDivider

            UsageSection(
                icon: "calendar",
                title: "This Week",
                tokens: tracker.weeklyTokens,
                limit: tracker.config.weeklyTokenLimit,
                percentage: tracker.weeklyPercentage,
                outputTokens: tracker.weeklyOutputTokens,
                detail: tracker.weeklyDetail
            )

            sectionDivider
            footerSection
        }
        .frame(width: 320)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                // Claude branded dot
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.coral, Theme.amber],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 14, height: 14)

                Text("claude")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.coral, Theme.amber],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(1.5)
            }

            Text("USAGE MONITOR")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .tracking(3)
        }
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer
    private var footerSection: some View {
        HStack(spacing: 8) {
            // Status indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(tracker.hasData ? Color.green : Color.gray)
                    .frame(width: 5, height: 5)
                Text(tracker.hasData ? "Updated \(tracker.lastUpdatedText)" : "No data")
                    .font(.system(size: 10))
            }
            .foregroundColor(Theme.textSecondary)

            Spacer()

            // Config button
            Button(action: { tracker.openConfig() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(FooterButtonStyle())
            .help("Edit limits & settings")

            // Refresh button
            Button(action: {
                tracker.refresh()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(FooterButtonStyle())
            .help("Refresh now")

            // Quit button
            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 10))
            }
            .buttonStyle(FooterButtonStyle())
            .help("Quit")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Theme.divider.opacity(0.5))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}

// MARK: - Usage Section
struct UsageSection: View {
    let icon: String
    let title: String
    let tokens: Int
    let limit: Int
    let percentage: Double
    let outputTokens: Int
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title row with percentage
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.coral)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Text("\(Int(min(percentage, 9.99) * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.progressColor(for: percentage))
                    .monospacedDigit()
            }

            // Progress bar
            GradientProgressBar(progress: percentage)
                .frame(height: 10)

            // Token details
            HStack(spacing: 0) {
                Text(Theme.formatTokens(tokens))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textPrimary.opacity(0.9))

                Text(" / \(Theme.formatTokens(limit)) tokens")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                Text(Theme.formatTokens(outputTokens) + " out")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary.opacity(0.7))
            }

            // Detail line
            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Gradient Progress Bar
struct GradientProgressBar: View {
    let progress: Double

    private var barColors: [Color] {
        Theme.progressColors(for: progress)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 5)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
                    )

                // Fill
                if progress > 0.005 {
                    let fillWidth = max(10, geo.size.width * CGFloat(min(progress, 1.0)))

                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: barColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth)
                        .shadow(color: barColors[0].opacity(0.4), radius: 6, x: 0, y: 0)
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: progress)
    }
}

// MARK: - Button Styles
struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Theme.coral : Theme.textSecondary)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Theme.surface : Color.clear)
            )
            .contentShape(Rectangle())
    }
}
