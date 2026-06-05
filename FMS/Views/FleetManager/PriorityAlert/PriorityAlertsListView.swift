import SwiftUI

struct PriorityAlertsListView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedCategory: String
    @Namespace private var categoryNamespace

    init(initialSelectedCategory: String = "SOS Alerts") {
        _selectedCategory = State(initialValue: initialSelectedCategory)
    }

    // Computed from live service data so counts update in real-time
    private var categories: [(name: String, icon: String, color: Color, count: Int)] {
        let sosCount = appViewModel.service.sosAlerts.filter { $0.status == "ACTIVE" }.count
        let criticalCount = appViewModel.service.workOrders.filter { $0.priority == .critical && $0.status != .completed }.count
        let maintenanceCount = appViewModel.service.maintenanceSchedules.filter { $0.status == .overdue }.count
        return [
            ("SOS Alerts",  "exclamationmark.triangle.fill", Color(red: 1, green: 0.25, blue: 0.3),  sosCount),
            ("Critical",    criticalCount > 0 ? "bell.badge.fill" : "bell.fill",               Color(red: 1, green: 0.45, blue: 0.1),  criticalCount),
            ("Maintenance", "wrench.and.screwdriver.fill",   Color(red: 0.35, green: 0.6, blue: 1),  maintenanceCount),
            ("Off-Route",   "location.slash.fill",           Color(red: 1, green: 0.75, blue: 0.1),  0),
            ("Geofence",    "shield.slash.fill",             Color(red: 0.6, green: 0.3, blue: 1),   0),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Category Tab Bar ──────────────────────────────────────
            categoryTabBar
                .padding(.bottom, 8)

            Divider()
                .background(AppTheme.border)

            // ── Alert List ────────────────────────────────────────────
            PriorityAlertDetailView(category: selectedCategory,
                                    count: categoryCount(selectedCategory))
                .id(selectedCategory)          // force re-render on tab switch
        }
        .background(AppTheme.background)
        .navigationTitle("Priority Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Category Tab Bar
    private var categoryTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.name) { cat in
                    categoryTab(cat)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)
        }
    }

    private func categoryTab(_ cat: (name: String, icon: String, color: Color, count: Int)) -> some View {
        let isSelected = selectedCategory == cat.name

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                selectedCategory = cat.name
            }
        } label: {
            HStack(spacing: 7) {
                // Icon
                Image(systemName: cat.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : cat.color)

                // Label
                Text(cat.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)

                // Count Badge
                if cat.count > 0 {
                    Text("\(cat.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isSelected ? cat.color : .white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(
                            Capsule()
                                .fill(isSelected ? .white : cat.color)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [cat.color, cat.color.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: cat.color.opacity(0.45), radius: 8, y: 4)
                        .matchedGeometryEffect(id: "selectedTab", in: categoryNamespace)
                } else {
                    Capsule()
                        .fill(AppTheme.surfaceSecondary)
                        .overlay(
                            Capsule()
                                .strokeBorder(cat.color.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func categoryCount(_ name: String) -> Int {
        categories.first { $0.name == name }?.count ?? 0
    }
}

#Preview {
    NavigationStack {
        PriorityAlertsListView()
            .environment(AppViewModel())
    }
}
