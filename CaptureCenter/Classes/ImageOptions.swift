//
//  ImageType.swift
//  Pods
//
//  Created by Mingloan Chan on 7/19/17.
//
//

import Foundation

public enum ImageType {
    case JPEG
    case PNG
}

public struct ImageOptions {
    var imageType = ImageType.JPEG
    var targetWidth: CGFloat = 1024.0
    var targetHeight: CGFloat = 1024.0
}
