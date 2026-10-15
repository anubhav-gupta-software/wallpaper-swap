//
//  ImagePrep.swift
//  WallpaperSwap
//

import ImageIO
import UIKit

enum ImagePrep {
    /// Decode a library or camera photo upright, and cap the long edge so the
    /// crop screen doesn't try to hold a 48 megapixel bitmap.
    static func prepare(data: Data, maxPixel: CGFloat = 4096) -> UIImage? {
        thumbnail(data: data, maxPixel: maxPixel) ?? UIImage(data: data)
    }

    static func prepare(_ image: UIImage, maxPixel: CGFloat = 4096) -> UIImage {
        guard let data = image.jpegData(compressionQuality: 0.95),
              let prepared = thumbnail(data: data, maxPixel: maxPixel) else {
            return image
        }
        return prepared
    }

    private static func thumbnail(data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}
