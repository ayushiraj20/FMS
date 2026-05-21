import SwiftUI

struct AppScaffold<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            AppTheme.ambientGradient
                .opacity(0.9)
                .ignoresSafeArea()

            Circle()
                .fill(AppTheme.brand.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 80)
                .offset(x: 140, y: -240)

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 280, height: 280)
                .blur(radius: 120)
                .offset(x: -160, y: 260)

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
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.glass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
            )
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
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
            VStack(alignment: .leading, spacing: 10) {
                Text(stat.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(stat.value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(stat.detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(stat.trend)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.brand)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RoleBadgeView: View {
    let role: UserRole

    var body: some View {
        Label(role.rawValue, systemImage: role.iconName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.brand.opacity(0.14))
            .foregroundStyle(AppTheme.brand)
            .clipShape(Capsule())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(AppTheme.gradient.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(AppTheme.glass.opacity(configuration.isPressed ? 0.7 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
