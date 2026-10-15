//
//  WallpaperRenderer.swift
//  WallpaperSwap
//

import UIKit

enum DeviceScreen {
    static func portraitPixels() -> CGSize {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let bounds = scene?.screen.nativeBounds.size ?? CGSize(width: 1179, height: 2556)
        if bounds.width <= bounds.height { return bounds }
        return CGSize(width: bounds.height, height: bounds.width)
    }

    static var aspect: CGFloat {
        let size = portraitPixels()
        guard size.height > 0 else { return 9.0 / 19.5 }
        return size.width / size.height
    }
}

enum CropGeometry {
    static func fillScale(imageSize: CGSize, cropSize: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1 }
        return max(cropSize.width / imageSize.width, cropSize.height / imageSize.height)
    }

    static func clampedOffset(offset: CGSize, imageSize: CGSize, cropSize: CGSize, scale: CGFloat) -> CGSize {
        let fill = fillScale(imageSize: imageSize, cropSize: cropSize)
        let displayed = CGSize(
            width: imageSize.width * fill * scale,
            height: imageSize.height * fill * scale
        )
        let maxX = max(0, (displayed.width - cropSize.width) / 2)
        let maxY = max(0, (displayed.height - cropSize.height) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    /// The portion of the image (in its own point space) visible in the crop.
    static func sourceRect(imageSize: CGSize, cropSize: CGSize, scale: CGFloat, offset: CGSize) -> CGRect {
        let safeScale = max(scale, 0.01)
        let clamped = clampedOffset(offset: offset, imageSize: imageSize, cropSize: cropSize, scale: safeScale)
        let displayScale = fillScale(imageSize: imageSize, cropSize: cropSize) * safeScale
        guard displayScale > 0 else {
            return CGRect(origin: .zero, size: imageSize)
        }
        let visible = CGSize(width: cropSize.width / displayScale, height: cropSize.height / displayScale)
        var origin = CGPoint(
            x: (imageSize.width - visible.width) / 2 - clamped.width / displayScale,
            y: (imageSize.height - visible.height) / 2 - clamped.height / displayScale
        )
        origin.x = min(max(0, origin.x), max(0, imageSize.width - visible.width))
        origin.y = min(max(0, origin.y), max(0, imageSize.height - visible.height))
        return CGRect(origin: origin, size: visible)
    }
}

enum WallpaperRenderer {
    static func render(image: UIImage, viewSize: CGSize, scale: CGFloat, offset: CGSize) -> UIImage {
        guard viewSize.width > 1, viewSize.height > 1, image.size.width > 1, image.size.height > 1 else {
            return image
        }
        let pixels = DeviceScreen.portraitPixels()
        let source = CropGeometry.sourceRect(
            imageSize: image.size,
            cropSize: viewSize,
            scale: scale,
            offset: offset
        )
        guard source.width > 1, source.height > 1 else { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: pixels, format: format)
        return renderer.image { _ in
            let scaleX = pixels.width / source.width
            let scaleY = pixels.height / source.height
            let destination = CGRect(
                x: -source.origin.x * scaleX,
                y: -source.origin.y * scaleY,
                width: image.size.width * scaleX,
                height: image.size.height * scaleY
            )
            image.draw(in: destination)
        }
    }
}
