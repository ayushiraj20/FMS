import SwiftUI

struct BroadcastRowView: View {
    let message: BroadcastMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.title)
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.textPrimary)
                    
                    Text(message.sentAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(DriverTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "megaphone.fill")
                    .font(.subheadline)
                    .foregroundStyle(DriverTheme.accent)
                    .padding(8)
                    .background(DriverTheme.accent.opacity(0.15), in: Circle())
            }

            Text(message.message)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(DriverTheme.textSecondary)
                .lineLimit(3)

            Divider().background(DriverTheme.textSecondary.opacity(0.2))

            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DriverTheme.accent)
                Text(message.senderName)
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(DriverTheme.textPrimary)
                Spacer()
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .scrollTransition { content, phase in
            content.scaleEffect(phase.isIdentity ? 1 : 0.95).opacity(phase.isIdentity ? 1 : 0.8)
        }
    }
}
