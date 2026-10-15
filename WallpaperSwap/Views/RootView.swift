//
//  RootView.swift
//  WallpaperSwap
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .top) {
            Ink.background.ignoresSafeArea()
            if model.needsIntro {
                OnboardingView()
            } else {
                VStack(spacing: 0) {
                    Group {
                        switch model.selectedTab {
                        case .home:
                            HomeView()
                        case .history:
                            HistoryView()
                        case .guide:
                            GuideView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    tabBar
                }
                if let banner = model.banner {
                    Text(banner)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Ink.text)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Ink.raised, in: Capsule())
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.snappy, value: model.banner)
        .preferredColorScheme(.dark)
        .tint(Ink.accent)
        .modelErrorAlert()
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !model.needsIntro else { return }
            Task { await model.refresh() }
        }
        .task(id: model.banner) {
            guard model.banner != nil else { return }
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            model.banner = nil
        }
        .onOpenURL { _ in
            model.selectedTab = .home
        }
    }

    private var tabBar: some View {
        HStack {
            tabButton(.home, "Home", "photo")
            tabButton(.history, "History", "square.grid.2x2")
            tabButton(.guide, "Guide", "list.number")
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Ink.background)
        .overlay(alignment: .top) {
            Rectangle().fill(Ink.line).frame(height: 0.5)
        }
    }

    private func tabButton(_ tab: AppTab, _ title: String, _ symbol: String) -> some View {
        let selected = model.selectedTab == tab
        return Button {
            model.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.body.weight(selected ? .semibold : .regular))
                Text(title)
                    .font(.caption2.weight(selected ? .semibold : .regular))
            }
            .foregroundStyle(selected ? Ink.accent : Ink.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension View {
    /// Presents AppModel.lastError. Sheets and the crop cover each need
    /// their own modifier, because an alert on the root doesn't show above them.
    func modelErrorAlert() -> some View {
        modifier(ModelErrorAlert())
    }
}

private struct ModelErrorAlert: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.alert(
            "Something didn't work",
            isPresented: Binding(
                get: { model.lastError != nil },
                set: { show in
                    if !show { model.lastError = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.lastError ?? "")
        }
    }
}
