//
//  UIImage+Helpers.swift
//  Pods
//
//  Created by Mingloan Chan on 7/19/17.
//
//

import Foundation
import UIKit

struct Size {
    var width: CGFloat
    var height: CGFloat
}

extension UIImage {
    
    /**
     Compress UIImage and output Data
     - Parameter ratio:   The ratio of rect to crop.
     - Returns: A new cropped image.
     */
    func compressToSize(_ targetSize: Size, outputType: ImageType) -> UIImage? {
        var actualWidth = size.width
        var actualHeight = size.height
        
        var imgRatio = actualWidth / actualHeight
        let maxRatio = targetSize.width / targetSize.height
        
        // to make sure image need to resize by checking actual size and target size
        if (actualHeight > targetSize.height || actualWidth > targetSize.width) {
            if imgRatio < maxRatio {
                //adjust width according to maxHeight
                imgRatio = targetSize.height / actualHeight
                actualWidth = imgRatio * actualWidth
                actualHeight = targetSize.height
            }
            else if imgRatio > maxRatio {
                //adjust height according to maxWidth
                imgRatio = targetSize.width / actualWidth
                actualHeight = imgRatio * actualHeight
                actualWidth = targetSize.width
            }
            else {
                actualHeight = targetSize.height
                actualWidth = targetSize.width
            }
        }
        
        let rect = CGRect(x: 0, y: 0, width: actualWidth, height: actualHeight)
        UIGraphicsBeginImageContext(rect.size)
        draw(in: rect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func orientationForFlippingHorizontally(source isCGImage: Bool) -> UIImageOrientation {
        switch imageOrientation {
        case .up:
            return isCGImage ? .downMirrored : .upMirrored
        case .down:
            return isCGImage ? .upMirrored : .downMirrored
        case .left:
            return isCGImage ? .rightMirrored : .leftMirrored
        case .right:
            return isCGImage ? .leftMirrored : .rightMirrored
        case .upMirrored:
            return isCGImage ? .down : .up
        case .downMirrored:
            return isCGImage ? .up : .down
        case .leftMirrored:
            return isCGImage ? .right : .left
        case .rightMirrored:
            return isCGImage ? .left : .right
        }
    }
}
