//
//  FriendPhotoWidget.swift
//  WallpaperSwapWidget
//

import SwiftUI
import UIKit
import WidgetKit

struct WallpaperEntry: TimelineEntry {
    var date: Date
    var image: UIImage?
    var caption: String
    var receivedAt: Date?
}

struct WallpaperProvider: TimelineProvider {
    func placeholder(in context: Context) -> WallpaperEntry {
        WallpaperEntry(date: .now, image: nil, caption: "Maya", receivedAt: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (WallpaperEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WallpaperEntry>) -> Void) {
        let entry = load()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> WallpaperEntry {
        let image = WallpaperStore.shared.loadCurrentImage()
        let meta = WallpaperStore.shared.loadCurrentMeta()
        return WallpaperEntry(
            date: .now,
            image: image,
            caption: meta?.caption ?? "Wallpaper Swap",
            receivedAt: meta?.date
        )
    }
}

struct FriendPhotoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FriendPhoto", provider: WallpaperProvider()) { entry in
            FriendPhotoView(entry: entry)
        }
        .configurationDisplayName("Friend's Photo")
        .description("The latest photo they sent you, edge to edge.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}

struct FriendPhotoView: View {
    var entry: WallpaperEntry
    @Environment(\.widgetFamily) private var family

    private var isInline: Bool { family == .accessoryInline }
    private var isAccessory: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            return true
        default:
            return false
        }
    }

    var body: some View {
        content
            .widgetURL(URL(string: "wallpaperswap://latest"))
            .containerBackground(for: .widget) {
                background
            }
    }

    @ViewBuilder
    private var content: some View {
        if isInline {
            Text(entry.image == nil ? "Wallpaper Swap" : entry.caption)
        } else if isAccessory {
            photo
        } else {
            caption
        }
    }

    @ViewBuilder
    private var background: some View {
        if isAccessory {
            Color.clear
        } else if entry.image != nil {
            photo
        } else {
            emptyPlate
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let image = entry.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            emptyPlate
        }
    }

    private var caption: some View {
        VStack {
            Spacer()
            if entry.image != nil {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.caption)
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(.white)
                        if let receivedAt = entry.receivedAt {
                            Text(receivedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    private var emptyPlate: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.07, blue: 0.06),
                    Color(red: 0.45, green: 0.16, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 4) {
                Text("Wallpaper Swap")
                    .font(.system(.caption, design: .serif))
                Text("No photo yet")
                    .font(.system(.caption2))
                    .opacity(0.8)
            }
            .foregroundStyle(Color(red: 0.965, green: 0.945, blue: 0.906))
            .padding(8)
        }
    }
}

@main
struct WallpaperSwapWidgetBundle: WidgetBundle {
    var body: some Widget {
        FriendPhotoWidget()
    }
}
