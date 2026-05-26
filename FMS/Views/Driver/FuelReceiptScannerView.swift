import SwiftUI

struct FuelReceiptScannerView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Mocked Scanned Details
    @State private var station = "HP Petrol Pump Lonavala"
    @State private var liters = "45.2L"
    @State private var amount = "₹4,518"
    @State private var selectedDate = Date()
    @State private var odometer = "45,230 km"
    
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Scanner UI Mock / Camera Trigger
                        Button {
                            showCamera = true
                        } label: {
                            ZStack {
                                if let img = capturedImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity, maxHeight: 300)
                                        .clipped()
                                } else {
                                    Color.black
                                }
                                
                                VStack {
                                    Spacer()
                                    
                                    // Orange scanner frame
                                    ZStack {
                                        Rectangle()
                                            .fill(Color.orange.opacity(0.1))
                                        
                                        // Corners
                                        Group {
                                            CornerView(alignment: .topLeading)
                                            CornerView(alignment: .topTrailing)
                                            CornerView(alignment: .bottomLeading)
                                            CornerView(alignment: .bottomTrailing)
                                        }
                                    }
                                    .frame(width: 280, height: 180)
                                    
                                    Spacer()
                                    
                                    Text(capturedImage == nil ? "Tap to scan receipt within frame" : "Tap to retake")
                                        .font(.subheadline)
                                        .foregroundStyle(.gray)
                                        .padding(.bottom, 20)
                                }
                            }
                        }
                        .frame(height: 300)
                        
                        VStack(spacing: 16) {
                            // Scanned Details
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Scanned Details")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(.bottom, 4)
                                
                                editableRow(label: "Station", text: $station)
                                editableRow(label: "Liters", text: $liters)
                                editableRow(label: "Amount", text: $amount)
                                
                                HStack {
                                    Text("Date")
                                        .font(.subheadline)
                                        .foregroundStyle(.gray)
                                    Spacer()
                                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .colorScheme(.dark) // Match the dark UI theme
                                }
                                .padding(.vertical, 4)
                            }
                            .padding(16)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            // Odometer Reading
                            HStack {
                                Text("Odometer Reading")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                Spacer()
                                TextField("Odometer", text: $odometer)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 120)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(16)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            // Recent Fuel Entries
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Fuel Entries")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(.bottom, 4)
                                
                                recentEntryRow(date: "19 May 2026", liters: "45.2L", amount: "₹4,518")
                                recentEntryRow(date: "19 May 2026", liters: "45.2L", amount: "₹4,518")
                                
                                Spacer().frame(height: 60) // Space for submit button
                            }
                            .padding(16)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                }
                .ignoresSafeArea(edges: .top)
                
                // Submit Button
                VStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Submit")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule().fill(DriverTheme.accent))
                    }
                    .padding()
                    .background(
                        LinearGradient(colors: [Color(uiColor: .systemBackground).opacity(0), Color(uiColor: .systemBackground)], startPoint: .top, endPoint: .bottom)
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        Image(systemName: "bolt.fill").foregroundStyle(.white)
                        Toggle("", isOn: .constant(false)).labelsHidden()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                            .font(.title3)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $capturedImage, onCapture: { _ in })
                .ignoresSafeArea()
        }
    }
    
    private func editableRow(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.gray)
            Spacer()
            TextField(label, text: text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
    
    private func recentEntryRow(date: String, liters: String, amount: String) -> some View {
        HStack {
            Text(date)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(liters)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(amount)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.subheadline)
        .foregroundStyle(.gray)
        .padding(.vertical, 2)
    }
}

private struct CornerView: View {
    var alignment: Alignment
    var body: some View {
        Path { path in
            switch alignment {
            case .topLeading:
                path.move(to: CGPoint(x: 0, y: 20))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 0))
            case .topTrailing:
                path.move(to: CGPoint(x: -20, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 20))
            case .bottomLeading:
                path.move(to: CGPoint(x: 0, y: -20))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 0))
            case .bottomTrailing:
                path.move(to: CGPoint(x: -20, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: -20))
            default:
                break
            }
        }
        .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        .frame(width: 20, height: 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}
