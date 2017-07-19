//
//  PhotoCaptureDelegate.swift
//
//  Created by Mingloan Chan on 10/10/2016.
//  Copyright © 2016. All rights reserved.
//

import AVFoundation
import Photos

@available(iOS 10.0, *)
class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    
    fileprivate(set) var requestedPhotoSettings: AVCapturePhotoSettings
    
    fileprivate let willCapturePhotoAnimation: () -> ()
    
    fileprivate let completed: (PhotoCaptureDelegate, Data?) -> ()
    
    fileprivate var photoData: Data? = nil
    
    init(with requestedPhotoSettings: AVCapturePhotoSettings, willCapturePhotoAnimation: @escaping () -> (), completed: @escaping (PhotoCaptureDelegate, Data?) -> ()) {
        self.requestedPhotoSettings = requestedPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.completed = completed
    }
    
    fileprivate func didFinish() {
        completed(self, photoData)
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, willCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapturePhotoAnimation()
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let photoSampleBuffer = photoSampleBuffer {
            photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
        }
        else {
            print("Error capturing photo: \(String(describing: error))")
            return
        }
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        
        defer {
            didFinish()
        }
        
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let _ = photoData else {
            print("No photo data resource")
            return
        }
    }
    
}
