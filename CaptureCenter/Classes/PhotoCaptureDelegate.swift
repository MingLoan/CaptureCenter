//
//  PhotoCaptureDelegate.swift
//
//  Created by Mingloan Chan on 10/10/2016.
//  Copyright © 2016. All rights reserved.
//

import AVFoundation
import Photos

func processCaptureData(_ data: Data, options: ImageOptions, captureDevicePosition: AVCaptureDevicePosition, previewViewSize: CGSize) -> CaptureResult {
    
    var finalData: Data?
    
    // crop image with preview size
    guard let image = UIImage(data: data), let cgImage = image.cgImage else { return CaptureResult.empty }
    var finalRect = AVMakeRect(aspectRatio: previewViewSize, insideRect: CGRect(origin: CGPoint.zero, size: image.size))
    // check whether image rotated after converting to CGImage
    if Int(image.size.width) == cgImage.height {
        finalRect = CGRect(x: finalRect.minY, y: finalRect.minX, width: finalRect.height, height: finalRect.width)
    }
    guard let imageRef = cgImage.cropping(to: finalRect) else { return CaptureResult.empty }
    let croppedImage = UIImage(cgImage: imageRef, scale: image.scale, orientation: image.imageOrientation)
    var flippedImage = croppedImage
    // flip image for selfie
    if captureDevicePosition == .front {
        flippedImage = UIImage(cgImage: imageRef, scale: image.scale, orientation: image.orientationForFlippingHorizontally(source: true))
    }
    
    if case let .custom(width, height) = options.imageSize {
        let targetSize = Size(width: width, height: height)
        guard let finalImage = flippedImage.compressToSize(targetSize, outputType: options.imageType) else { return CaptureResult.empty }
        finalData = UIImageJPEGRepresentation(finalImage, options.JPEGCompression)
    }
    else {
        finalData = UIImageJPEGRepresentation(flippedImage, options.JPEGCompression)
    }
    return CaptureResult.stillImage(imageData: finalData!)
}

@available(iOS 10.0, *)
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    
    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    
    private let willCapturePhotoAnimation: () -> ()
    
    private let livePhotoCaptureHandler: (Bool) -> ()
    
    private let completionHandler: (PhotoCaptureDelegate, CaptureResult) -> ()
    
    private var photoData: Data? = nil
    
    private var livePhotoCompanionMovieURL: URL?
    
    private weak var captureCenter: CaptureCenter?
    private var imageOptions: ImageOptions
    
    init(with requestedPhotoSettings: AVCapturePhotoSettings,
         captureCenter: CaptureCenter?,
         imageOptions: ImageOptions,
         willCapturePhotoAnimation: @escaping () -> (),
         livePhotoCaptureHandler: @escaping (Bool) -> (),
         completionHandler: @escaping (PhotoCaptureDelegate, CaptureResult) -> ()) {
        
        self.requestedPhotoSettings = requestedPhotoSettings
        self.captureCenter = captureCenter
        self.imageOptions = imageOptions
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
    
    // Final delegate method, for cleaning up resources
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        
        if let error = error {
            print("Error capturing photo: \(error)")
            completionHandler(self, CaptureResult.empty)
            return
        }
        
        guard let photoData = photoData else {
            print("No photo data resource")
            completionHandler(self, CaptureResult.empty)
            return
        }
        
        let afterSavingToLibrary: (PHAsset?) -> () = { asset in
            if let _ = self.livePhotoCompanionMovieURL {
                print("return live photo")
                guard let asset = asset else {
                    self.completionHandler(self, CaptureResult.empty)
                    return
                }
                self.processLivePhotoWithPHAsset(asset)
            }
            else {
                print("process still image")
                self.completionHandler(self, self.processStillImage())
            }
        }
        
        PHPhotoLibrary.requestAuthorization { [unowned self] status in
            if status == .authorized {
                
                var placeholderIdentifier: String?
                PHPhotoLibrary.shared().performChanges({ [unowned self] in
                    
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()
                    //options.uniformTypeIdentifier = self.requestedPhotoSettings.processedFileType.map { $0.rawValue }
                    creationRequest.addResource(with: .photo, data: photoData, options: options)
                    
                    if let livePhotoCompanionMovieURL = self.livePhotoCompanionMovieURL {
                        let livePhotoCompanionMovieFileResourceOptions = PHAssetResourceCreationOptions()
                        livePhotoCompanionMovieFileResourceOptions.shouldMoveFile = true
                        creationRequest.addResource(with: .pairedVideo, fileURL: livePhotoCompanionMovieURL, options: livePhotoCompanionMovieFileResourceOptions)
                    }
                    
                    placeholderIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier
                    
                }, completionHandler: { _, error in
                    if let error = error {
                        print("Error occurered while saving photo to photo library: \(error)")
                    }
                    guard let placeholderIdentifier = placeholderIdentifier else {
                        print("no placeholder asset")
                        return
                    }
                    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [placeholderIdentifier], options: nil)
                    guard let asset = assets.firstObject else {
                        print("cannot fetch asset")
                        return
                    }
                    afterSavingToLibrary(asset)
                })
            }
            else {
                afterSavingToLibrary(nil)
            }
        }
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
    
    // raw data delegates
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingRawPhotoSampleBuffer rawSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
    }
    
    // private methods
    private func processStillImage() -> CaptureResult {
        guard let captureCenter = captureCenter, let photoData = photoData else {
            return CaptureResult.empty
        }
        let previewViewSize = captureCenter.previewView.bounds.size
        let captureDevicePosition = captureCenter.captureDevicePosition
        return processCaptureData(photoData, options: imageOptions, captureDevicePosition: captureDevicePosition, previewViewSize: previewViewSize)
    }
    
    private func processLivePhotoWithPHAsset(_ asset: PHAsset) {
        guard let _ = livePhotoCompanionMovieURL else {
            completionHandler(self, CaptureResult.empty)
            return
        }
        var targetSize = CGSize.zero
        if case let .custom(width, height) = imageOptions.imageSize {
            targetSize = CGSize(width: width, height: height)
        }
        PHImageManager.default().requestLivePhoto(for: asset,
                                                  targetSize: targetSize,
                                                  contentMode: .aspectFill,
                                                  options: nil) { (livePhoto, info) in
                                                    if let info = info, let isThumbnail = info[PHImageResultIsDegradedKey] as? Bool, isThumbnail {
                                                        return
                                                    }
                                                    guard let livePhoto = livePhoto else {
                                                        self.completionHandler(self, CaptureResult.empty)
                                                        return
                                                    }
                                                    self.completionHandler(self, CaptureResult.livePhoto(livePhoto: livePhoto))
                                                }
    }
}
