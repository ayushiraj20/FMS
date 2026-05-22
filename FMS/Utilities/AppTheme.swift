import SwiftUI
import UIKit

enum AppTheme {
    // MARK: - Brand Colors
    static let brand = Color.dynamic(light: "#FF6B35", dark: "#FF8A50")
    static let brandDark = Color.dynamic(light: "#E55A2B", dark: "#FF6B35")

    // MARK: - Backgrounds
    static let background = Color.dynamic(light: "#FFFFFF", dark: "#000000")
    static let surface = Color.dynamic(light: "#FFFFFF", dark: "#1C1C1E")
    static let surfaceSecondary = Color.dynamic(light: "#F2F2F7", dark: "#2C2C2E")

    // MARK: - Glass & Border
    static let glass = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor.white.withAlphaComponent(0.06)
        } else {
            return UIColor.black.withAlphaComponent(0.03)
        }
    })
    static let border = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor.white.withAlphaComponent(0.10)
        } else {
            return UIColor.black.withAlphaComponent(0.08)
        }
    })

    // MARK: - Card Styles
    static let cardBackground = Color.dynamic(light: "#FFFFFF", dark: "#1C1C1E")
    static let cardShadowColor = Color.dynamic(light: "#000000", dark: "#000000")

    // MARK: - Text
    static let textPrimary = Color.dynamic(light: "#1C1C1E", dark: "#F5F5F7")
    static let textSecondary = Color.dynamic(light: "#8E8E93", dark: "#98989D")

    // MARK: - Status Colors
    static let success = Color.dynamic(light: "#34C759", dark: "#30D158")
    static let warning = Color.dynamic(light: "#FF9500", dark: "#FFB340")
    static let error = Color.dynamic(light: "#FF3B30", dark: "#FF453A")

    // MARK: - Gradients
    static let gradient = LinearGradient(
        colors: [
            Color.dynamic(light: "#FF6B35", dark: "#FF8A50"),
            Color.dynamic(light: "#FF8A50", dark: "#FFAB76")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ambientGradient = LinearGradient(
        colors: [
            Color.dynamic(light: "#FFFFFF", dark: "#000000"),
            Color.dynamic(light: "#FFF8F4", dark: "#0A0604"),
            Color.dynamic(light: "#FFFFFF", dark: "#000000")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Badge Colors
    static let badgeCritical = Color.dynamic(light: "#FF3B30", dark: "#FF453A")
    static let badgeAction = Color.dynamic(light: "#FF9500", dark: "#FFB340")
    static let badgeSuccess = Color.dynamic(light: "#34C759", dark: "#30D158")
}

// MARK: - Driver Theme (iOS 26 Light Mode)
enum DriverTheme {
    static let accent = Color(hex: "FD5D23")
    static let background = Color.white
    static let cardFill = Color(hex: "F2F2F7")
    static let elevatedCard = Color.white
    static let textPrimary = Color.black
    static let textSecondary = Color(UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.6))
    static let separator = Color(UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.3))
    static let criticalRed = Color(hex: "FF3B30")
    static let successGreen = Color(hex: "34C759")
    static let warningAmber = Color(hex: "FF9500")
    static let cardBorder = Color(hex: "E5E5EA")

    static let cardShadow = Color.black.opacity(0.06)
    static let glassWhite = Color.white.opacity(0.6)

    static let accentGradient = LinearGradient(
        colors: [Color(hex: "FD5D23"), Color(hex: "FF7A45")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Driver Glass Card
struct DriverGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DriverTheme.elevatedCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(DriverTheme.cardBorder, lineWidth: 0.5)
                    )
                    .shadow(color: DriverTheme.cardShadow, radius: 8, x: 0, y: 2)
            )
    }
}

// MARK: - Driver Accent Button Style
struct DriverAccentButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill(isDestructive ? DriverTheme.criticalRed : DriverTheme.accent)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Driver Pill Button Style (smaller)
struct DriverPillButtonStyle: ButtonStyle {
    var fillColor: Color = DriverTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(fillColor)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let title: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(color))
    }
}

// MARK: - Circular Progress Ring
struct CircularProgressRing: View {
    let progress: Double
    let size: CGFloat
    let strokeWidth: CGFloat
    var trackColor: Color = Color(hex: "E5E5EA")
    var progressColor: Color = DriverTheme.accent

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(progressColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: progress)
        }
        .frame(width: size, height: size)
    }
}

struct ThemeConfigurator {
    static func configure() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor.systemBackground
        tabAppearance.shadowColor = UIColor.separator

        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel
        ]
        tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color("AccentColor"))
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color("AccentColor"))
        ]

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color("AccentColor"))
    }
}

extension Color {
    static func dynamic(light: String, dark: String) -> Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(Color(hex: dark))
            } else {
                return UIColor(Color(hex: light))
            }
        })
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
