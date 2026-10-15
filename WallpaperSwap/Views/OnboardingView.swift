//
//  OnboardingView.swift
//  WallpaperSwap
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0
    @State private var draft = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 12)
            pageContent
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 28)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Ink.accent : Ink.line)
                            .frame(width: index == page ? 22 : 7, height: 7)
                    }
                }
                .accessibilityHidden(true)

                Button(page == 2 ? "Start swapping" : "Next") {
                    advance()
                }
                .buttonStyle(FillButtonStyle())
                .disabled(page == 2 && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Ink.background)
        }
        .onChange(of: page) { _, newPage in
            nameFocused = newPage == 2
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case 0:
            story(
                eyebrow: "Wallpaper Swap",
                title: "Their photo,\nyour screen.",
                body: "Pair with one friend. The pictures you send each other are cropped to a phone screen and become the wallpaper on the other side."
            )
        case 1:
            story(
                eyebrow: "How it actually lands",
                title: "A widget, and a real wallpaper.",
                body: "iOS won't let an app set the wallpaper itself. The photo fills a Home Screen and Lock Screen widget, and a Shortcut can set the real one. The guide walks through both."
            )
        default:
            VStack(alignment: .leading, spacing: 18) {
                story(
                    eyebrow: "Just you two",
                    title: "What should they call you?",
                    body: "Nearby pairing works with a free Apple ID, on the same Wi-Fi. You can also try the whole thing alone on this iPhone."
                )
                TextField("Your name", text: $draft)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .font(Ink.serif(28))
                    .foregroundStyle(Ink.text)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Ink.line).frame(height: 1)
                    }
                    .onSubmit { advance() }
            }
        }
    }

    private func story(eyebrow: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Ink.gold)
            Text(title)
                .font(Ink.serif(40))
                .foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(body)
                .font(.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func advance() {
        if page < 2 {
            Haptics.tap()
            withAnimation(.snappy) { page += 1 }
            return
        }
        if model.completeIntro(name: draft) {
            Haptics.success()
        }
    }
}
