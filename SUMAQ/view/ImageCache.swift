// ImageCache.swift
// SUMAQ

import UIKit
import ImageIO
import MobileCoreServices

final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 64 * 1024 * 1024
        return c
    }()

    private init() {}

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ img: UIImage, forKey key: String) {
        let cost = img.cgImage?.bytesPerRow ?? 4096 * Int(img.size.height)
        cache.setObject(img, forKey: key as NSString, cost: cost)
    }

    func downsampled(from data: Data, maxDimension: CGFloat = 1600) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, options) else { return nil }

        let w = maxDimension
        let h = maxDimension
        let opts = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(w, h)
        ] as CFDictionary

        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts) else { return nil }
        return UIImage(cgImage: cg)
    }
}

