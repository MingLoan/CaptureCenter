//
//  Options.swift
//  Pods
//
//  Created by Mingloan Chan on 7/19/17.
//
//

import Foundation

public enum ImageType {
    case JPEG
    @available(iOS 10.0, *)
    case livePhoto // fallback to JPEG if live photo capture is not supported
}

public enum ImageSize {
    case normal
    case highResolution // fallback to normal if high res photo capture is not supported
    case custom(width: CGFloat, height: CGFloat)
}

public enum VideoSize {
    case duration(timeInterval: TimeInterval)
    case fileSize(bytes: Int64)
}

public struct ImageOptions {
    var imageType = ImageType.JPEG
    // set if imageType is .JPEG
    var JPEGCompression: CGFloat = 1.0
    var imageSize = ImageSize.custom(width: 1024.0, height: 1024.0)
    
    public init(imageType: ImageType, imageSize: ImageSize = ImageSize.custom(width: 1024.0, height: 1024.0), JPEGCompression: CGFloat = 1.0) {
        self.imageType = imageType
        self.imageSize = imageSize
        self.JPEGCompression = JPEGCompression
    }
}
