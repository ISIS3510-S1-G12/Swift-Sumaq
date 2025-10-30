//
//  ImageCache.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDOÑO on 30/10/25.
//

import UIKit
import ImageIO
import MobileCoreServices

final class ImageCache {
    static let shared = ImageCache(countLimit: 300, costLimit: 64 * 1024 * 1024)

    private let lru: LRUCache<String, UIImage>

    init(countLimit: Int, costLimit: Int) {
        self.lru = LRUCache<String, UIImage>(countLimit: countLimit, costLimit: costLimit)
    }

    // API usada por RemoteImage (debe ser síncrona)
    func image(forKey key: String) -> UIImage? {
        lru.value(for: key)
    }

    func set(_ image: UIImage, forKey key: String) {
        lru.set(image, for: key, cost: image.memoryCost)
    }

    func removeAll() {
        lru.removeAll()
    }

    // Downsample para ahorrar RAM en fotos grandes
    func downsampled(from data: Data,
                     hintUTI: CFString = kUTTypeJPEG,
                     maxDimension: CGFloat = 900) -> UIImage? {
        let srcOpts: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceTypeIdentifierHint: hintUTI
        ]
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts as CFDictionary) else {
            return UIImage(data: data)
        }

        let px = Int(maxDimension * UIScreen.main.scale)
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: px
        ]
        guard let cgimg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgimg, scale: UIScreen.main.scale, orientation: .up)
    }
}

private extension UIImage {
    var memoryCost: Int {
        guard let cg = cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }
}
