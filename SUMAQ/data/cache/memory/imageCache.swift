//
//  imageCache.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDO�O on 30/10/25.
//

import UIKit
import ImageIO
import MobileCoreServices

public actor ImageCache {
    public static let shared = ImageCache()

    // Ajusta límites según tu app (p. ej., 300 imgs o 64 MB)
    private let lru = LRUCache<String, UIImage>(countLimit: 300,
                                                costLimit: 64 * 1024 * 1024)

    public func image(forKey key: String) -> UIImage? {
        await lru.value(for: key)
    }

    public func set(_ image: UIImage, forKey key: String) {
        await lru.set(image, for: key, cost: image.memoryCost)
    }

    // ---- Utilidades (no tocan estado del actor)
    nonisolated var thumbnailMaxDimension: CGFloat { 900 } // para fotos de review en feed

    /// Crea un thumbnail downsampleado desde Data (mucho más barato en RAM).
    nonisolated func downsampled(from data: Data,
                                 hintUTI: CFString = kUTTypeJPEG) -> UIImage? {
        let srcOpts: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceTypeIdentifierHint: hintUTI
        ]
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts as CFDictionary)
        else { return UIImage(data: data) }

        let maxDim = Int(thumbnailMaxDimension * UIScreen.main.scale)
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDim
        ]
        guard let cgimg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
        else { return UIImage(data: data) }
        return UIImage(cgImage: cgimg, scale: UIScreen.main.scale, orientation: .up)
    }
}

// Costo aproximado en bytes que ocupa el UIImage en memoria
private extension UIImage {
    var memoryCost: Int {
        guard let cg = cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }
}
