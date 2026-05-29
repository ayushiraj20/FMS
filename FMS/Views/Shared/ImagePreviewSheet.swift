import SwiftUI

struct ImagePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let image: Image?
    let imageURLString: String?

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Group {
                    if let image = image {
                        image
                            .resizable()
                            .scaledToFit()
                    } else if let urlString = imageURLString, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .controlSize(.large)
                                    .tint(.white)
                            case .success(let img):
                                img
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.slash")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.gray)
                                    Text("Could not load receipt image")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundStyle(.gray)
                                }
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.slash")
                                .font(.system(size: 44))
                                .foregroundStyle(.gray)
                            Text("No image available")
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .offset(offset)
                .scaleEffect(scale)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            if scale > 1.0 {
                                lastOffset = offset
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            scale = min(max(newScale, 1.0), 4.0)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale <= 1.0 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                                lastScale = 2.0
                            }
                        }
                    }
                )
            }
            .navigationTitle("Receipt Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(.white)
                }
            }
        }
    }
}
