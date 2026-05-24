import SwiftUI

struct AppScaffold<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            content
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .shadow(
                        color: AppTheme.cardShadowColor.opacity(0.06),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 0.5)
            )
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
    }
}

struct StatCardView: View {
    let stat: KPIStat

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(stat.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Image(systemName: stat.iconName)
                        .font(.title3)
                        .foregroundStyle(Color("AccentColor"))
                }

                Text(stat.value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                if let badgeText = stat.badgeText {
                    Text(badgeText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(badgeDisplayColor(stat.badgeColor))
                        )
                } else {
                    Text(stat.trend)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color("AccentColor"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func badgeDisplayColor(_ type: KPIStat.BadgeColorType) -> Color {
        switch type {
        case .none: return Color("AccentColor")
        case .critical: return AppTheme.badgeCritical
        case .action: return AppTheme.badgeAction
        case .success: return AppTheme.badgeSuccess
        }
    }
}

struct RoleBadgeView: View {
    let role: UserRole

    var body: some View {
        Label(role.rawValue, systemImage: role.iconName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.brand.opacity(0.12))
            .foregroundStyle(AppTheme.brand)
            .clipShape(Capsule())
    }
}

struct StatusBadgeView: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }
}

struct AvatarView: View {
    let name: String
    let size: CGFloat

    var body: some View {
        let initials = name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
        
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            colorForName(name),
                            colorForName(name).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(initials.isEmpty ? "U" : initials)
                .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
    
    private func colorForName(_ name: String) -> Color {
        let hash = abs(name.hashValue)
        let colors: [Color] = [
            Color(hex: "#00a2ff"), // Blue
            Color(hex: "#34c759"), // Green
            Color(hex: "#ff9500"), // Orange
            Color(hex: "#af52de"), // Purple
            Color(hex: "#ff2d55"), // Pink
            Color(hex: "#ff3b30")  // Red
        ]
        return colors[hash % colors.count]
    }
}

struct FilterChipView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.brand : AppTheme.surfaceSecondary)
                )
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.brand)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppTheme.brand)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.brand.opacity(0.10))
                    .opacity(configuration.isPressed ? 0.7 : 1)
            )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        GlassCard {
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.brand)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct LoadingStateView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppTheme.brand)
            Text(title)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(AppTheme.brand)
                        .shadow(color: AppTheme.brand.opacity(0.4), radius: 12, x: 0, y: 6)
                )
        }
    }
}

struct SearchFieldStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.clear)
    }
}

extension View {
    func appListStyle() -> some View {
        modifier(SearchFieldStyleModifier())
    }
}
