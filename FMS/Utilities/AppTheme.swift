import SwiftUI
import UIKit

enum AppTheme {
    static let brand = Color.dynamic(light: "#00C853", dark: "#00E676")
    static let background = Color.dynamic(light: "#F7F9F6", dark: "#060B08")
    static let surface = Color.dynamic(light: "#FFFFFF", dark: "#111A15")
    static let glass = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor.white.withAlphaComponent(0.06)
        } else {
            return UIColor.black.withAlphaComponent(0.04)
        }
    })
    static let border = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor.white.withAlphaComponent(0.08)
        } else {
            return UIColor.black.withAlphaComponent(0.06)
        }
    })
    static let textPrimary = Color.dynamic(light: "#1A241E", dark: "#F5F7FA")
    static let textSecondary = Color.dynamic(light: "#5A6B60", dark: "#9EAB9F")
    static let success = Color.dynamic(light: "#27AE60", dark: "#2ECC71")
    static let warning = Color.dynamic(light: "#F39C12", dark: "#FFB547")
    static let error = Color.dynamic(light: "#C0392B", dark: "#D62828")
    static let gradient = LinearGradient(
        colors: [
            Color.dynamic(light: "#00C853", dark: "#00E676"),
            Color.dynamic(light: "#00B0FF", dark: "#05C3DE")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let ambientGradient = LinearGradient(
        colors: [
            Color.dynamic(light: "#E8F5E9", dark: "#0C2016"),
            Color.dynamic(light: "#F7F9F6", dark: "#060B08"),
            Color.dynamic(light: "#EDF2EE", dark: "#08140F")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct ThemeConfigurator {
    static func configure() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(AppTheme.surface)
        tabAppearance.shadowColor = UIColor.clear
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppTheme.textSecondary)
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.textSecondary)]
        tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppTheme.brand)
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.brand)]
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppTheme.textPrimary)]
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.textPrimary)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
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
