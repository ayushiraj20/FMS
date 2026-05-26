import SwiftUI

struct BroadcastInboxView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var broadcastService = BroadcastService.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if broadcastService.isLoading {
                    VStack(spacing: 20) {
                        ProgressView().scaleEffect(1.5).tint(DriverTheme.accent)
                        Text("Loading Broadcasts...").font(.subheadline).foregroundStyle(DriverTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else if broadcastService.messages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(DriverTheme.accent.opacity(0.4))
                            .symbolEffect(.pulse)
                        Text("No Broadcasts")
                            .font(.system(.title3, design: .rounded).bold())
                        Text("Fleet manager messages will appear here")
                            .font(.subheadline)
                            .foregroundStyle(DriverTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(broadcastService.messages) { message in
                            BroadcastRowView(message: message)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(DriverScreenBackground())
        .navigationTitle("Broadcasts")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadBroadcasts()
        }
    }

    func loadBroadcasts() async {
        guard let orgID = appViewModel.currentOrganization?.id else { return }
        await BroadcastService.shared.load(orgID: orgID)
    }
}

#Preview {
    NavigationStack {
        BroadcastInboxView()
            .environment(AppViewModel())
    }
}
