//
//  CaptureResult.swift
//  Pods
//
//  Created by Mingloan Chan on 7/25/17.
//
//

import Foundation
import Photos
import AVFoundation

public enum CaptureResult {
    case empty
    case stillImage(imageData: Data)
    @available(iOS 9.1, *)
    case livePhoto(livePhoto: PHLivePhoto)
}
