//
//  Components.swift
//  WallpaperSwap
//

import SwiftUI
import UIKit

struct PhonePreview: View {
    var image: UIImage?
    var chrome: Chrome
    var emptyTitle: String
    var emptyDetail: String

    enum Chrome {
        case lock
        case home
    }

    var body: some View {
        GeometryReader { geo in
            let size = fittedSize(in: geo.size)
            ZStack {
                RoundedRectangle(cornerRadius: size.width * 0.16, style: .continuous)
                    .fill(Color.black)
                screen(width: size.width - 12)
                    .frame(width: size.width - 12, height: size.height - 12)
                    .clipShape(RoundedRectangle(cornerRadius: size.width * 0.13, style: .continuous))
                RoundedRectangle(cornerRadius: size.width * 0.16, style: .continuous)
                    .strokeBorder(Ink.line, lineWidth: 1)
            }
            .frame(width: size.width, height: size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: .black.opacity(0.45), radius: 28, y: 18)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if image == nil {
            return "\(emptyTitle). \(emptyDetail)"
        }
        return "Wallpaper preview"
    }

    private func fittedSize(in bounds: CGSize) -> CGSize {
        let aspect = max(DeviceScreen.aspect, 0.4)
        let widthIfFullHeight = bounds.height * aspect
        if widthIfFullHeight <= bounds.width {
            return CGSize(width: widthIfFullHeight, height: bounds.height)
        }
        let height = bounds.width / aspect
        return CGSize(width: bounds.width, height: height)
    }

    private func screen(width: CGFloat) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Ink.surface
                VStack(spacing: 8) {
                    Text(emptyTitle)
                        .font(Ink.serif(width * 0.09))
                        .foregroundStyle(Ink.text)
                        .multilineTextAlignment(.center)
                    Text(emptyDetail)
                        .font(.system(size: max(11, width * 0.045)))
                        .foregroundStyle(Ink.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 18)
            }
            if image != nil {
                chromeOverlay(width: width)
            }
        }
    }

    @ViewBuilder
    private func chromeOverlay(width: CGFloat) -> some View {
        switch chrome {
        case .lock:
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(spacing: 2) {
                    Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(size: max(10, width * 0.045), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(context.date.formatted(.dateTime.hour().minute()))
                        .font(.system(size: width * 0.22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                    Spacer()
                    Capsule()
                        .fill(.white.opacity(0.85))
                        .frame(width: width * 0.32, height: 4)
                        .padding(.bottom, width * 0.04)
                }
                .padding(.top, width * 0.16)
            }
        case .home:
            VStack {
                HStack {
                    Text(Date.now.formatted(.dateTime.hour().minute()))
                        .font(.system(size: max(10, width * 0.04), weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, width * 0.06)
                .padding(.top, width * 0.045)
                Spacer()
                HStack(spacing: width * 0.035) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: width * 0.04, style: .continuous)
                            .fill(.white.opacity(0.22))
                            .frame(width: width * 0.14, height: width * 0.14)
                    }
                }
                .padding(.vertical, width * 0.035)
                .padding(.horizontal, width * 0.04)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: width * 0.07, style: .continuous))
                .padding(.horizontal, width * 0.045)
                .padding(.bottom, width * 0.05)
            }
        }
    }
}

struct ScreenCaption: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(Ink.serif(28))
                .foregroundStyle(Ink.text)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Ink.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
    }
}

struct ChoiceChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? Ink.onAccent : Ink.secondary)
                .background(isSelected ? Ink.accent : Ink.raised, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
