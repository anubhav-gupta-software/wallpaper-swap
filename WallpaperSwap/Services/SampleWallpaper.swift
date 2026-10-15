//
//  SampleWallpaper.swift
//  WallpaperSwap
//

import UIKit

enum SampleWallpaper {
    /// A stand-in photo so the Shortcut and the widget can be tried before
    /// a friend sends anything.
    static func render() -> UIImage {
        let size = DeviceScreen.portraitPixels()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let colors = [
                UIColor(red: 0.11, green: 0.07, blue: 0.05, alpha: 1).cgColor,
                UIColor(red: 0.55, green: 0.16, blue: 0.10, alpha: 1).cgColor,
                UIColor(red: 0.89, green: 0.76, blue: 0.48, alpha: 1).cgColor
            ]
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 0.58, 1]) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width * 0.2, y: size.height),
                    options: []
                )
            } else {
                UIColor(red: 0.55, green: 0.16, blue: 0.10, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }

            context.cgContext.setFillColor(UIColor(white: 1, alpha: 0.16).cgColor)
            let diameter = size.width * 0.78
            context.cgContext.fillEllipse(in: CGRect(
                x: size.width * 0.32,
                y: size.height * 0.16,
                width: diameter,
                height: diameter
            ))

            let titleFont = UIFont.systemFont(ofSize: size.width * 0.16, weight: .regular)
            let serif = UIFont(
                descriptor: titleFont.fontDescriptor.withDesign(.serif) ?? titleFont.fontDescriptor,
                size: size.width * 0.18
            )
            let title = NSAttributedString(string: "for you", attributes: [
                .font: serif,
                .foregroundColor: UIColor(red: 0.965, green: 0.945, blue: 0.906, alpha: 1)
            ])
            let titleSize = title.size()
            let titleY = size.height * 0.64
            title.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: titleY))

            let subtitle = NSAttributedString(string: "WALLPAPER SWAP", attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: size.width * 0.032, weight: .medium),
                .foregroundColor: UIColor(red: 0.965, green: 0.945, blue: 0.906, alpha: 0.82),
                .kern: 3.5
            ])
            let subtitleSize = subtitle.size()
            subtitle.draw(at: CGPoint(
                x: (size.width - subtitleSize.width) / 2,
                y: titleY + titleSize.height + size.width * 0.04
            ))
        }
    }
}
