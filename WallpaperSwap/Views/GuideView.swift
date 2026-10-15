//
//  GuideView.swift
//  WallpaperSwap
//

import SwiftUI
import UIKit

struct GuideView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Set it")
                    .font(Ink.serif(34))
                    .foregroundStyle(Ink.text)
                Text("The app can deliver the photo. iOS still has to be the one that changes the wallpaper.")
                    .font(.body)
                    .foregroundStyle(Ink.secondary)

                ForEach(GuideCopy.sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .font(Ink.serif(24))
                            .foregroundStyle(Ink.text)
                        Text(section.intro)
                            .font(.subheadline)
                            .foregroundStyle(Ink.secondary)
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(section.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Ink.onAccent)
                                        .frame(width: 22, height: 22)
                                        .background(Ink.accent, in: Circle())
                                    Text(step)
                                        .font(.subheadline)
                                        .foregroundStyle(Ink.text)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Ink.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }

                VStack(spacing: 10) {
                    Button("Open Shortcuts") {
                        guard let url = URL(string: "shortcuts://") else { return }
                        openURL(url)
                    }
                    .buttonStyle(FillButtonStyle())

                    Button("Copy the Shortcut steps") {
                        UIPasteboard.general.string = GuideCopy.shortcutPlainText
                        model.banner = "Steps copied."
                    }
                    .buttonStyle(FillButtonStyle(prominent: false))

                    Button("Put a sample photo on my screen") {
                        model.useSample()
                        model.selectedTab = .home
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Ink.gold)
                    .frame(minHeight: 40)
                }
            }
            .padding(20)
        }
    }
}

enum GuideCopy {
    struct Section: Identifiable {
        let id: String
        let title: String
        let intro: String
        let steps: [String]
    }

    static let sections: [Section] = [
        Section(
            id: "widget",
            title: "Home Screen and Lock Screen widgets",
            intro: "The widgets are full-bleed: the photo goes to the edge of the widget, with no extra padding. The large Home Screen widget is the one that feels like a wallpaper. Lock Screen widgets are smaller, and iOS may tint them.",
            steps: [
                "Touch and hold the Home Screen until the icons jiggle, then tap +.",
                "Search for Wallpaper Swap and add the large widget. Medium and small are the same photo, cropped tighter.",
                "For the Lock Screen, touch and hold it, tap Customize, then Lock Screen.",
                "Tap a widget slot under the clock, search for Wallpaper Swap, and add the rectangular or circular one. Done.",
                "A free Apple ID can install the widget, but it can't sign an App Group. Until you turn that on with a paid developer account, the widget stays on its empty state. The Shortcut below still works."
            ]
        ),
        Section(
            id: "shortcut",
            title: "Set the real wallpaper",
            intro: "Wallpaper Swap publishes a Shortcuts action called Get Latest Wallpaper. It returns the newest photo on your screen, including a sample. Run the shortcut once so iOS can ask permission.",
            steps: [
                "Open this app once so iOS notices the action. If Shortcuts can't find it, force-quit Shortcuts and open it again.",
                "In Shortcuts, tap + and add Get Latest Wallpaper. It lives under Wallpaper Swap.",
                "Add Set Wallpaper. Tap its photo and choose the Latest Wallpaper variable from the action above.",
                "On Set Wallpaper, open the details and turn off Show Preview. Choose Lock Screen, Home Screen, or Both.",
                "If that photo field is greyed out, set any photo as your wallpaper in Settings once, then come back and pick the variable.",
                "Name it Apply Friend Wallpaper. Run it and approve the prompts.",
                "To run it when a photo arrives: Automation, App, Wallpaper Swap, Is Opened, Run Immediately, and run this shortcut. iOS may still ask the first time. You can also add the shortcut to your Home Screen and tap it."
            ]
        )
    ]

    static var shortcutPlainText: String {
        let steps = sections.first { $0.id == "shortcut" }?.steps ?? []
        return (["Wallpaper Swap — set the real wallpaper"] + steps.enumerated().map { "\($0.offset + 1). \($0.element)" })
            .joined(separator: "\n")
    }
}
