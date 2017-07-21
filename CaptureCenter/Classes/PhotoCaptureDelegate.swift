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
    
    private let livePhotoCaptureHandler: (Bool) -> ()
    
    fileprivate let completionHandler: (PhotoCaptureDelegate, Data?) -> ()
    
    fileprivate var photoData: Data? = nil
    
    private var livePhotoCompanionMovieURL: URL?
    
    init(with requestedPhotoSettings: AVCapturePhotoSettings,
         willCapturePhotoAnimation: @escaping () -> (),
         livePhotoCaptureHandler: @escaping (Bool) -> (),
         completionHandler: @escaping (PhotoCaptureDelegate, Data?) -> ()) {
        
        self.requestedPhotoSettings = requestedPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.livePhotoCaptureHandler = livePhotoCaptureHandler
        self.completionHandler = completionHandler
    }
    
    // Delegates
    
    func capture(_ captureOutput: AVCapturePhotoOutput, willBeginCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // live photo capture just start
        if resolvedSettings.livePhotoMovieDimensions.width > 0 && resolvedSettings.livePhotoMovieDimensions.height > 0 {
            livePhotoCaptureHandler(true)
        }
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, willCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapturePhotoAnimation()
        print("isFlashEnabled: \(resolvedSettings.isFlashEnabled)")
        print("isStillImageStabilizationEnabled: \(resolvedSettings.isStillImageStabilizationEnabled)")
        if #available(iOS 10.2, *) {
            print("isDualCameraFusionEnabled: \(resolvedSettings.isDualCameraFusionEnabled)")
        }
        print("photoDimensions: \(resolvedSettings.photoDimensions.width), \(resolvedSettings.photoDimensions.height)")
        
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {

    }
    
    // Process Photo
    
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?) {
        
        if let photoSampleBuffer = photoSampleBuffer {
            photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
        }
        else {
            print("Error capturing photo: \(String(describing: error))")
        }
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        
        if let error = error {
            print("Error capturing photo: \(error)")
            completionHandler(self, nil)
            return
        }
        
        guard let photoData = photoData else {
            print("No photo data resource")
            completionHandler(self, nil)
            return
        }
        
        
        if let livePhotoCompanionMoviePath = livePhotoCompanionMovieURL?.path {
            print("return live photo")
            // live photo capture
            if FileManager.default.fileExists(atPath: livePhotoCompanionMoviePath) {
                do {
                    try FileManager.default.removeItem(atPath: livePhotoCompanionMoviePath)
                } catch {
                    print("Could not remove file at url: \(livePhotoCompanionMoviePath)")
                }
            }
        }
        else {
            print("return still image")
            // still image capture
            completionHandler(self, photoData)
        }
        
        
        // save to album
        /*
         PHPhotoLibrary.requestAuthorization { [unowned self] status in
         if status == .authorized {
         PHPhotoLibrary.shared().performChanges({ [unowned self] in
         let options = PHAssetResourceCreationOptions()
         let creationRequest = PHAssetCreationRequest.forAsset()
         //options.uniformTypeIdentifier = self.requestedPhotoSettings.processedFileType.map { $0.rawValue }
         creationRequest.addResource(with: .photo, data: photoData, options: options)
         
         if let livePhotoCompanionMovieURL = self.livePhotoCompanionMovieURL {
         let livePhotoCompanionMovieFileResourceOptions = PHAssetResourceCreationOptions()
         livePhotoCompanionMovieFileResourceOptions.shouldMoveFile = true
         creationRequest.addResource(with: .pairedVideo, fileURL: livePhotoCompanionMovieURL, options: livePhotoCompanionMovieFileResourceOptions)
         }
         
         }, completionHandler: { [unowned self] _, error in
         if let error = error {
         print("Error occurered while saving photo to photo library: \(error)")
         }
         
         self.didFinish()
         }
         )
         } else {
         self.didFinish()
         }
         }*/
    }
    
    // Live photos delegates
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // live photo capture just stopped
        livePhotoCaptureHandler(false)
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplay photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        // movie file written
        if error != nil {
            print("Error processing live photo companion movie: \(String(describing: error))")
            return
        }
        print("live photo captured")
        print("\(outputFileURL)")
        livePhotoCompanionMovieURL = outputFileURL
    }
    
}
