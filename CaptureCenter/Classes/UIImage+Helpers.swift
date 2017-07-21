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
    func compressToSize(_ targetSize: Size, outputType: ImageType) -> Data? {
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
        
        guard let img = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        var imageData: Data?
        
        switch outputType {
        case .JPEG:
            imageData = UIImageJPEGRepresentation(img, 0.9)
            break
        case .PNG:
            imageData = UIImagePNGRepresentation(img)
            break
        default:
            break
        }
        return imageData
    }
    
    /**
     Crop Center Square From Image
     - Parameter ratio:   The ratio of rect to crop.
     - Returns: A new cropped image.
     */
    func centerArea(withRatio ratio: CGFloat) -> UIImage {
        
        let refWidth: CGFloat = CGFloat(cgImage!.width)
        let refHeight: CGFloat = CGFloat(cgImage!.height)
        
        if refWidth == 0 || refHeight == 0 {
            return self
        }
        
        let imageEdgeRatio = refWidth/refHeight
        
        var width: CGFloat = 0
        var height: CGFloat = 0
        if imageEdgeRatio > ratio {
            height = refHeight
            width = height * ratio
        }
        else {
            width = refWidth
            height = width/ratio
        }
        
        let x = (refWidth - width) / 2
        let y = (refHeight - height) / 2
        
        let cropRect = CGRect(x: x, y: y, width: ceil(width), height: ceil(height))
        if let imageRef = self.cgImage!.cropping(to: cropRect) {
            let cropped = UIImage(cgImage: imageRef, scale: 0, orientation: imageOrientation)
            return cropped
        }
        return self
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
