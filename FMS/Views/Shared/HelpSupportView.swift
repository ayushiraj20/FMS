import SwiftUI

struct HelpSupportView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var feedbackSent = false
    @State private var feedbackText = ""
    @State private var selectedFAQIndex: Int? = nil
    
    struct FAQItem {
        let question: String
        let answer: String
    }
    
    let faqs = [
        FAQItem(
            question: "How do I complete a work order?",
            answer: "Open the assigned work order from your dashboard or 'Orders' queue, tap the status dropdown, change it to 'Completed', enter any resolution notes or parts used, and save. This automatically notifies the Fleet Manager and updates the vehicle status."
        ),
        FAQItem(
            question: "How is the Today's Priority Queue determined?",
            answer: "Work orders are prioritized automatically based on the defect's safety impact. 'Critical' safety defects (e.g., brakes, steering) are placed at the top, followed by 'High', 'Medium', and 'Low' priority scheduled maintenance."
        ),
        FAQItem(
            question: "How do I update parts inventory?",
            answer: "Navigate to the 'Inventory' tab, tap on the part you want to update, enter the new quantity received or used, and tap save. If stock levels drop below the warning threshold, an automated restock request is generated."
        ),
        FAQItem(
            question: "What if a vehicle is missing from the system?",
            answer: "Check that the vehicle's registration/ID is correct. If the vehicle is newly acquired or not showing up, contact your Fleet Operations Lead to verify it has been onboarded into the organization fleet list."
        )
    ]
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Direct Support Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Contact Support")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(roleColor.opacity(0.8))
                            .padding(.leading, 8)
                        
                        GlassCard {
                            VStack(spacing: 16) {
                                // Hotline Call
                                Link(destination: URL(string: "tel:18005550199")!) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(roleColor.opacity(0.12))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "phone.fill")
                                                .foregroundStyle(roleColor)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Operations Control Center")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.textPrimary)
                                            Text("24/7 Breakdown & Assistance Hotline")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                }
                                
                                Divider().background(AppTheme.border)
                                
                                // Support Email
                                Link(destination: URL(string: "mailto:support@fleetos.com")!) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(roleColor.opacity(0.12))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "envelope.fill")
                                                .foregroundStyle(roleColor)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Email IT & App Support")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.textPrimary)
                                            Text("support@fleetos.com")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Frequently Asked Questions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Frequently Asked Questions")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(roleColor.opacity(0.8))
                            .padding(.leading, 8)
                        
                        VStack(spacing: 12) {
                            ForEach(0..<faqs.count, id: \.self) { index in
                                let faq = faqs[index]
                                let isOpen = selectedFAQIndex == index
                                
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedFAQIndex = isOpen ? nil : index
                                            }
                                        } label: {
                                            HStack {
                                                Text(faq.question)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(AppTheme.textPrimary)
                                                    .multilineTextAlignment(.leading)
                                                Spacer()
                                                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                                    .font(.caption)
                                                    .foregroundStyle(roleColor)
                                            }
                                        }
                                        
                                        if isOpen {
                                            Text(faq.answer)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.textSecondary)
                                                .transition(.opacity)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // App Feedback Form
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Send App Feedback")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(roleColor.opacity(0.8))
                            .padding(.leading, 8)
                        
                        GlassCard {
                            VStack(spacing: 12) {
                                if feedbackSent {
                                    VStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.largeTitle)
                                            .foregroundStyle(AppTheme.success)
                                        Text("Thank You!")
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text("Your feedback helps us make FleetOS better.")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                } else {
                                    TextField("Describe the issue or feedback...", text: $feedbackText, axis: .vertical)
                                        .lineLimit(4...8)
                                        .font(.subheadline)
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AppTheme.border, lineWidth: 1)
                                        )
                                    
                                    Button {
                                        submitFeedback()
                                    } label: {
                                        Text("Submit Feedback")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(roleColor)
                                            )
                                    }
                                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var roleColor: Color {
        guard let role = appViewModel.currentUser?.role else {
            return AppTheme.brand
        }
        switch role {
        case .fleetManager:
            return AppTheme.brand
        case .driver:
            return Color(hex: "FD5D23")
        case .maintenance:
            return Color(hex: "#FF5A1F")
        }
    }
    
    private func submitFeedback() {
        feedbackSent = true
    }
}

#Preview {
    NavigationStack {
        HelpSupportView()
            .environment(AppViewModel())
    }
}
