//
//  CaptureMode.swift
//  Pods
//
//  Created by Mingloan Chan on 7/25/17.
//
//

import AVFoundation

public enum CaptureMode {
    case photo
    case video(size: VideoSize, location: URL, didStart: () -> (), progress: (CGFloat) -> (), willFinish: () -> (), completion: (AVAsset?) -> ())
    case stream
}
public func ==(lhs: CaptureMode, rhs: CaptureMode) -> Bool {
    switch (lhs, rhs) {
    case (.photo, .photo),
         (.video(_, _, _, _, _, _), .video(_, _, _, _, _, _)),
         (.stream, .stream):
        return true
    default:
        return false
    }
}
