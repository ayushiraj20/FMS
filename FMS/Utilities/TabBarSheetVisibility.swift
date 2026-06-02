import SwiftUI

private struct TabBarSheetDepthKey: EnvironmentKey {
    static let defaultValue: Binding<Int>? = nil
}

extension EnvironmentValues {
    var tabBarSheetDepth: Binding<Int>? {
        get { self[TabBarSheetDepthKey.self] }
        set { self[TabBarSheetDepthKey.self] = newValue }
    }
}

extension View {
    /// Attach to the root `TabView` for each role so sheets can hide the tab bar underneath.
    func tabBarSheetDepthTracking(_ depth: Binding<Int>) -> some View {
        environment(\.tabBarSheetDepth, depth)
    }

    /// Call on the view that presents a sheet/fullScreenCover.
    func hidesTabBarWhileSheet(isPresented: Bool) -> some View {
        toolbar(isPresented ? .hidden : .automatic, for: .tabBar)
    }

    /// Hides the tab bar when this view is pushed onto a NavigationStack.
    func hideTabBarOnPush() -> some View {
        toolbar(.hidden, for: .tabBar)
    }

    /// Call on the root content inside every `.sheet` / `.fullScreenCover`.
    func registersSheetPresentation() -> some View {
        modifier(TabBarSheetPresentationModifier())
    }
}

private struct TabBarSheetPresentationModifier: ViewModifier {
    @Environment(\.tabBarSheetDepth) private var tabBarSheetDepth

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard let tabBarSheetDepth else { return }
                tabBarSheetDepth.wrappedValue += 1
            }
            .onDisappear {
                guard let tabBarSheetDepth else { return }
                tabBarSheetDepth.wrappedValue = max(0, tabBarSheetDepth.wrappedValue - 1)
            }
    }
}
