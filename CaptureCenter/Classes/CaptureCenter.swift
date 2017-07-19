//
//  LiveCaptureCenter.swift
//
//  Created by Mingloan Chan on 29/4/2016.
//  Copyright © 2016. All rights reserved.
//

import Foundation
import AVFoundation

public enum VideoSize {
    case duration(timeInterval: TimeInterval)
    case fileSize(bytes: Int64)
}

public enum CaptureMode {
    case stillImage
    case video(size: VideoSize, location: URL, delegateObject: AVCaptureFileOutputRecordingDelegate)
    case gif(size: VideoSize, location:URL, delegateObject: AVCaptureFileOutputRecordingDelegate)
}

public final class CaptureCenter: NSObject {
    
    // MARK: - Factory Methods
    static func getAVCaptureVideoOrientation(_ orientation:UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return nil
        }
    }
    
    // get device for iOS9 or less
    fileprivate func deviceWithPosition(_ position:AVCaptureDevicePosition) -> AVCaptureDevice? {
        for device in AVCaptureDevice.devices() {
            if let device = device as? AVCaptureDevice {
                if (device.hasMediaType(AVMediaTypeVideo) && device.position == position) {
                    return device
                }
            }
        }
        return nil
    }
    
    // Public Properties
    public let previewView = PreviewView()
    public var currentFlashMode = AVCaptureFlashMode.off {
        didSet {
            set(flashMode: currentFlashMode)
        }
    }
    public var currentTorchMode = AVCaptureTorchMode.off {
        didSet {
            set(flashMode: currentFlashMode)
        }
    }
    
    // value from 0 to 1
    var zoomPercentage: CGFloat = 0
    
    // capture mode
    fileprivate(set) var captureMode = CaptureMode.stillImage
    
    // Public Readonly Properties
    fileprivate(set) var hasFlash = false
    fileprivate(set) var hasTorch = false
    fileprivate(set) var videoMaxZoomFactor: CGFloat = 1
    fileprivate(set) var currentZoomScale: CGFloat = 1 {
        didSet {
            DispatchQueue.main.async {
                if self.videoMaxZoomFactor > 1 {
                    self.zoomPercentage = (self.currentZoomScale - 1)/(self.videoMaxZoomFactor - 1)
                }
            }
        }
    }
    
    // Private Properties
    fileprivate(set) var cameraControls = false
    
    fileprivate enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    fileprivate let session = AVCaptureSession()
    
    fileprivate var isSessionRunning = false
    fileprivate var isSessionCongifured = false
    
    fileprivate let sessionQueue = DispatchQueue(label: "session queue", attributes: [])
    
    fileprivate var setupResult: SessionSetupResult = .success
    
    // MARK: - CaptureDeviceInput
    fileprivate var videoDeviceInput: AVCaptureDeviceInput?
    fileprivate var captureDevicePosition = AVCaptureDevicePosition.unspecified
    fileprivate var audioDeviceInput: AVCaptureDeviceInput?
    
    // MARK: - CaptureDeviceOutput
    // iOS 8, 9 Image Output
    fileprivate let imageOutput: AVCaptureStillImageOutput = {
        let stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecJPEG]
        return stillImageOutput
    }()
    
    // iOS 10 Photo Output
    fileprivate var _photoOutput: AnyObject?
    fileprivate var inProgressPhotoCaptureDelegates = [Int64 : AnyObject]()
    
    @available(iOS 10.0, *)
    fileprivate var photoOutput: AVCapturePhotoOutput? {
        get {
            if let photoOutput = _photoOutput as? AVCapturePhotoOutput {
                return photoOutput
            }
            let output = AVCapturePhotoOutput()
            output.isHighResolutionCaptureEnabled = false
            output.isLivePhotoCaptureEnabled = false
            _photoOutput = output
            return output
        }
        set {
            _photoOutput = newValue
        }
    }
    
    // Video Output
    fileprivate var movieFileOutput: AVCaptureMovieFileOutput?
    fileprivate var backgroundRecordingID: UIBackgroundTaskIdentifier? = nil
    
    // Deinit
    deinit {
        
    }
    
    // MARK: - Capture Methods
    @discardableResult
    public func startCapturing(_ devicePosition: AVCaptureDevicePosition, from vc: UIViewController, cameraControlShouldOn: Bool = false) -> AVCaptureSession? {
        
        cameraControls = cameraControlShouldOn
        
        previewView.session = session
        previewView.captureCenter = self
        previewView.canControlCamera = cameraControls
        
        sessionQueue.suspend()
        UIApplication.doesCameraAllowed(
            deniedAlert: "Please tap on \"Change Settings\" and toggle the Camera option.",
            confirmationClosure: { _ in
                self.setupResult = .notAuthorized
                vc.dismiss(animated: true, completion: nil)
            },
            fromViewController: vc) { granted, firstAsking in
                
                defer {
                    self.sessionQueue.resume()
                }
                
                if !granted {
                    self.setupResult = .notAuthorized
                    return
                }
        }

        /*
         Setup the capture session.
         In general it is not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Why not do all of this on the main queue?
         Because AVCaptureSession.startRunning() is a blocking call which can
         take a long time. We dispatch session setup to the sessionQueue so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        
        if !isSessionCongifured {
            sessionQueue.async { [weak self] in
                self?.configureSession(devicePosition)
            }
        }
        
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            switch strongSelf.setupResult {
            case .success:
                // Only setup observers and start the session running if setup succeeded.
                strongSelf.addObservers()
                strongSelf.session.startRunning()
                strongSelf.isSessionRunning = strongSelf.session.isRunning
                break
            case .notAuthorized:
                break
            case .configurationFailed:
                break
            }
        }
        
        return session
    }
    
    public func stopCapturing() {
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.setupResult == .success {
                
                if let currentVideoDevice = strongSelf.videoDeviceInput?.device {
                    NotificationCenter.default.removeObserver(
                        strongSelf,
                        name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                        object: currentVideoDevice)
                }
                
                strongSelf.session.stopRunning()
                strongSelf.isSessionRunning = strongSelf.session.isRunning
                strongSelf.removeObservers()
            }
        }
    }
    
    public func captureWithOptions(_ options: ImageOptions, completion: @escaping ((Data?) -> ())) {
        
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            if #available(iOS 10.0, *) {
                /*
                 Retrieve the video preview layer's video orientation on the main queue before
                 entering the session queue. We do this to ensure UI elements are accessed on
                 the main thread and session configuration is done on the session queue.
                 */
                let videoPreviewLayerOrientation = strongSelf.previewView.videoPreviewLayer.connection.videoOrientation
                
                // Update the photo output's connection to match the video orientation of the video preview layer.
                if let photoOutputConnection = strongSelf.photoOutput?.connection(withMediaType: AVMediaTypeVideo) {
                    photoOutputConnection.videoOrientation = videoPreviewLayerOrientation
                }
                
                // Capture a JPEG photo with flash set to auto and high resolution photo enabled.
                let photoSettings = AVCapturePhotoSettings()
                photoSettings.flashMode = .off
                photoSettings.isHighResolutionPhotoEnabled = false
                if photoSettings.availablePreviewPhotoPixelFormatTypes.count > 0 {
                    photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String : photoSettings.availablePreviewPhotoPixelFormatTypes.first!]
                }
                /*
                if self.livePhotoMode == .on && self.photoOutput.isLivePhotoCaptureSupported { // Live Photo capture is not supported in movie mode.
                    let livePhotoMovieFileName = NSUUID().uuidString
                    let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
                    photoSettings.livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
                }
                */
                // Use a separate object for the photo capture delegate to isolate each capture life cycle.
                let photoCaptureDelegate =
                    PhotoCaptureDelegate(
                        with: photoSettings,
                        willCapturePhotoAnimation: { [weak strongSelf] in
                            DispatchQueue.main.async {
                                strongSelf?.previewView.videoPreviewLayer.opacity = 0
                                UIView.animate(withDuration: 0.25, animations: {
                                    strongSelf?.previewView.videoPreviewLayer.opacity = 1
                                })
                            }
                    }, completed: { [weak strongSelf] photoCaptureDelegate, data in
                        guard let innerStrongSelf = strongSelf else { return }
                        
                        guard let imageData = data else { completion(nil); return }
                        innerStrongSelf.processCaptureData(imageData as Data, options: options, completion: completion)

                        // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
                        innerStrongSelf.sessionQueue.async { [weak innerStrongSelf] in
                            innerStrongSelf?.inProgressPhotoCaptureDelegates[photoCaptureDelegate.requestedPhotoSettings.uniqueID] = nil
                        }
                    }
                )
                
                /*
                 The Photo Output keeps a weak reference to the photo capture delegate so
                 we store it in an array to maintain a strong reference to this object
                 until the capture is completed.
                 */
                strongSelf.inProgressPhotoCaptureDelegates[photoCaptureDelegate.requestedPhotoSettings.uniqueID] = photoCaptureDelegate
                strongSelf.photoOutput?.capturePhoto(with: photoSettings, delegate: photoCaptureDelegate)
            }
            else {
                
                guard let videoConnection = strongSelf.imageOutput.connection(withMediaType: AVMediaTypeVideo) else { return }
                
                strongSelf.imageOutput.captureStillImageAsynchronously(from: videoConnection) { [weak strongSelf] (sampleBuffer, error) in
                    
                    guard let innerStrongSelf = strongSelf else { return }
                    
                    if let _ = error {
                        completion(nil)
                        return
                    }
                    
                    // for flash animation
//                    DispatchQueue.main.async {
//                        NotificationCenter.default.post(name: Notification.Name(rawValue: Global.Notification.liveFaceDidCaptureNotification), object: nil)
//                    }
                    
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    innerStrongSelf.processCaptureData(imageData!, options: options, completion: completion)
                }
            }
        }
    }
    
    fileprivate func processCaptureData(_ data: Data, options: ImageOptions, completion: ((Data?) -> ())) {
        
        var finalData: Data?
        let targetSize = Size(width: options.targetWidth, height: options.targetHeight)
        
        // flip image for selfie
        if captureDevicePosition == .front {
            guard
                let image = UIImage(data: data),
                let cgImage = image.cgImage
                else { completion(nil); return }
            
            let flippedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.orientationForFlippingHorizontally(source: true))
            finalData = flippedImage.compressToSize(targetSize, outputType: options.imageType)
        }
        else {
            guard let image = UIImage(data: data) else { completion(nil); return }
            finalData = image.compressToSize(targetSize, outputType: options.imageType)
        }
        
        guard
            let fData = finalData,
            let image = UIImage(data: fData) else { completion(nil); return }
        // crop image if according to preview size
        let finalRect = AVMakeRect(aspectRatio: previewView.bounds.size, insideRect: CGRect(origin: CGPoint.zero, size: image.size))
        let finalImage = image.centerArea(withRatio: finalRect.width/finalRect.height)
        
        finalData = UIImageJPEGRepresentation(finalImage, 1)
        completion(finalData)
    }
    
    public func toggleRecording() {
        guard let movieFileOutput = movieFileOutput else { return }
        
        /*
         Retrieve the video preview layer's video orientation on the main queue
         before entering the session queue. We do this to ensure UI elements are
         accessed on the main thread and session configuration is done on the session queue.
         */
        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection.videoOrientation
        
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            if !movieFileOutput.isRecording {
                
                //if UIDevice.currentDevice().multitaskingSupported {
                    /*
                     Setup background task.
                     This is needed because the `capture(_:, didFinishRecordingToOutputFileAt:, fromConnections:, error:)`
                     callback is not received until AVCam returns to the foreground unless you request background execution time.
                     This also ensures that there will be time to write the file to the photo library when AVCam is backgrounded.
                     To conclude this background execution, endBackgroundTask(_:) is called in
                     `capture(_:, didFinishRecordingToOutputFileAt:, fromConnections:, error:)` after the recorded file has been saved.
                     */
                    //self.backgroundRecordingID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler(nil)
                //}
                
                // Update the orientation on the movie file output video connection before starting recording.
                let movieFileOutputConnection = strongSelf.movieFileOutput?.connection(withMediaType: AVMediaTypeVideo)
                movieFileOutputConnection?.videoOrientation = videoPreviewLayerOrientation
                
                switch strongSelf.captureMode {
                case let .video(_, fileLocationURL, delegateObject):
                    movieFileOutput.startRecording(toOutputFileURL: fileLocationURL, recordingDelegate: delegateObject)
                    break
                case let .gif(_, fileLocationURL, delegateObject):
                    movieFileOutput.startRecording(toOutputFileURL: fileLocationURL, recordingDelegate: delegateObject)
                    break
                default:
                    break
                }
            }
            else {
                movieFileOutput.stopRecording()
            }
        }
    }
    
    // Call this on the session queue.
    fileprivate func configureSession(_ devicePosition: AVCaptureDevicePosition) {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        /*
         We do not create an AVCaptureMovieFileOutput when setting up the session because the
         AVCaptureMovieFileOutput does not support movie recording with AVCaptureSessionPresetPhoto.
         */
        session.sessionPreset = AVCaptureSessionPresetPhoto
        
        var videoDevice: AVCaptureDevice?
        if devicePosition == .back {
            if #available(iOS 10.0, *) {
                if let dualCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInDuoCamera, mediaType: AVMediaTypeVideo, position: .back) {
                    videoDevice = dualCameraDevice
                }
                else if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back) {
                    // If the back dual camera is not available, default to the back wide angle camera.
                    videoDevice = backCameraDevice
                }
                else {
                    videoDevice = self.deviceWithPosition(devicePosition)
                }
            }
            else {
                videoDevice = self.deviceWithPosition(devicePosition)
            }
        }
        else if devicePosition == .front {
            if #available(iOS 10.0, *) {
                videoDevice = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: devicePosition)
            }
            else {
                videoDevice = self.deviceWithPosition(devicePosition)
            }
        }
        
        guard let device = videoDevice else { return }
        
        // Add video input.
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: device)

            videoMaxZoomFactor = device.activeFormat.videoMaxZoomFactor
            
            if device.hasFlash {
                hasFlash = true
                currentFlashMode = device.flashMode
            }
            else {
                hasFlash = false
            }
            
            if device.hasTorch {
                hasTorch = true
                currentTorchMode = device.torchMode
            }
            else {
                hasTorch = false
            }
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(subjectAreaDidChange(_:)),
                    name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                    object: videoDeviceInput.device)
                
                self.videoDeviceInput = videoDeviceInput
                self.captureDevicePosition = devicePosition
            }
            else {
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
        catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        if #available(iOS 10.0, *) {
            // Add photo output.
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            else {
                print("Could not add photo output to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
        else {
            // Add image output.
            if session.canAddOutput(imageOutput) {
                session.addOutput(imageOutput)
            }
            else {
                print("Could not add photo output to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
        
        isSessionCongifured = true
        session.commitConfiguration()
        
        if let device = self.videoDeviceInput?.device {
            do {
                try device.lockForConfiguration()
                device.isSubjectAreaChangeMonitoringEnabled = true
                device.unlockForConfiguration()
            }
            catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }
    
    // MARK: - Toggle Capture Mode
    public func toggle(captureMode mode: CaptureMode, completion: @escaping ((Bool) -> ())) {
        
        captureMode = mode
        
        switch mode {
        case .stillImage:
            sessionQueue.async { [weak self] in
                guard let strongSelf = self else { return }

                /*
                 Remove the AVCaptureMovieFileOutput from the session because movie recording is
                 not supported with AVCaptureSessionPresetPhoto. Additionally, Live Photo
                 capture is not supported when an AVCaptureMovieFileOutput is connected to the session.
                 */
                strongSelf.session.beginConfiguration()
                strongSelf.session.removeOutput(strongSelf.movieFileOutput)
                strongSelf.session.sessionPreset = AVCaptureSessionPresetPhoto
                strongSelf.session.commitConfiguration()
                
                strongSelf.movieFileOutput = nil
                
                // Remove audio input.
                if let audioDeviceInput = strongSelf.audioDeviceInput {
                    strongSelf.session.removeInput(audioDeviceInput)
                }
                
                DispatchQueue.main.async {
                    completion(true)
                }
            }
            break
        case .video(let size, _, _):
            sessionQueue.async { [weak self] in
                guard let strongSelf = self else { return }
                
                strongSelf.session.beginConfiguration()

                // Add audio input.
                do {
                    let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
                    let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
                    strongSelf.audioDeviceInput = audioDeviceInput
                    
                    if strongSelf.session.canAddInput(audioDeviceInput) {
                        strongSelf.session.addInput(audioDeviceInput)
                    }
                    else {
                        print("Could not add audio device input to the session")
                    }
                }
                catch {
                    print("Could not create audio device input: \(error)")
                }
                
                let movieFileOutput = AVCaptureMovieFileOutput()
                switch size {
                case .duration(let seconds):
                    movieFileOutput.maxRecordedDuration = CMTime(seconds: seconds, preferredTimescale: 600)
                    break
                case .fileSize(let bytes):
                    movieFileOutput.maxRecordedFileSize = bytes
                    break
                }
                
                //movieFileOutput.minFreeDiskSpaceLimit = ???
                movieFileOutput.movieFragmentInterval = kCMTimeInvalid
                
                if strongSelf.session.canAddOutput(movieFileOutput) {
                    
                    strongSelf.session.addOutput(movieFileOutput)
                    strongSelf.session.sessionPreset = AVCaptureSessionPresetMedium
                    
                    if let connection = movieFileOutput.connection(withMediaType: AVMediaTypeVideo) {
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                    
                    strongSelf.movieFileOutput = movieFileOutput
                }
                
                strongSelf.session.commitConfiguration()
                
                DispatchQueue.main.async {
                    completion(true)
                }
            }
            break
        case .gif(let size, _, _):
            sessionQueue.async { [weak self] in
                guard let strongSelf = self else { return }
                
                strongSelf.session.beginConfiguration()
                
                // Remove audio input.
                if let audioDeviceInput = strongSelf.audioDeviceInput {
                    strongSelf.session.removeInput(audioDeviceInput)
                }
                
                let movieFileOutput = AVCaptureMovieFileOutput()
                switch size {
                case .duration(let seconds):
                    movieFileOutput.maxRecordedDuration = CMTime(seconds: seconds, preferredTimescale: 600)
                    break
                case .fileSize(let bytes):
                    movieFileOutput.maxRecordedFileSize = bytes
                    break
                }
                
                //movieFileOutput.minFreeDiskSpaceLimit = ???
                movieFileOutput.movieFragmentInterval = kCMTimeInvalid
                
                if strongSelf.session.canAddOutput(movieFileOutput) {
                    
                    strongSelf.session.addOutput(movieFileOutput)
                    strongSelf.session.sessionPreset = AVCaptureSessionPresetLow
                    
                    if let connection = movieFileOutput.connection(withMediaType: AVMediaTypeVideo) {
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                    
                    strongSelf.movieFileOutput = movieFileOutput
                }
                
                strongSelf.session.commitConfiguration()
                
                DispatchQueue.main.async {
                    completion(true)
                }
            }
            break
        }
    }
    
    // MARK: - Change Camera
    public func changeCamera(start startBlock: (() -> ()), finished endBlock: @escaping ((Bool) -> ())) {

        startBlock()

        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            let currentVideoDevice = strongSelf.videoDeviceInput?.device
            
            let currentPosition = currentVideoDevice?.position ?? .back
            var preferredPosition: AVCaptureDevicePosition
            
            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
                
            case .back:
                preferredPosition = .front
            }

            var videoDevice: AVCaptureDevice?
            
            if preferredPosition == .back {
                if #available(iOS 10.0, *) {
                    if let dualCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInDuoCamera, mediaType: AVMediaTypeVideo, position: .back) {
                        videoDevice = dualCameraDevice
                    }
                    else if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back) {
                        // If the back dual camera is not available, default to the back wide angle camera.
                        videoDevice = backCameraDevice
                    }
                    else {
                        videoDevice = strongSelf.deviceWithPosition(preferredPosition)
                    }
                }
                else {
                    videoDevice = strongSelf.deviceWithPosition(preferredPosition)
                }
            }
            else if preferredPosition == .front {
                if #available(iOS 10.0, *) {
                    videoDevice = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: preferredPosition)
                }
                else {
                    videoDevice = strongSelf.deviceWithPosition(preferredPosition)
                }
            }
            
            guard let newVideoDevice = videoDevice else { return }
            strongSelf.videoMaxZoomFactor = newVideoDevice.activeFormat.videoMaxZoomFactor
            
            if newVideoDevice.hasFlash {
                strongSelf.hasFlash = true
                strongSelf.currentFlashMode = newVideoDevice.flashMode
            }
            else {
                strongSelf.hasFlash = false
            }
            
            if newVideoDevice.hasTorch {
                strongSelf.hasTorch = true
                strongSelf.currentTorchMode = newVideoDevice.torchMode
            }
            else {
                strongSelf.hasTorch = false
            }
            
            do {
                let videoDeviceInput = try AVCaptureDeviceInput(device: newVideoDevice)
                
                strongSelf.session.beginConfiguration()
                
                // Remove the existing device input first, since using the front and back camera simultaneously is not supported.
                strongSelf.session.removeInput(strongSelf.videoDeviceInput)
                
                if strongSelf.session.canAddInput(videoDeviceInput) {
                    NotificationCenter.default.removeObserver(
                        strongSelf,
                        name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                        object: currentVideoDevice!)
                    
                    NotificationCenter.default.addObserver(
                        strongSelf,
                        selector: #selector(strongSelf.subjectAreaDidChange(_:)),
                        name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                        object: videoDeviceInput.device)
                    
                    strongSelf.session.addInput(videoDeviceInput)
                    strongSelf.videoDeviceInput = videoDeviceInput
                    strongSelf.captureDevicePosition = preferredPosition
                }
                else {
                    strongSelf.session.addInput(strongSelf.videoDeviceInput);
                }
                
                if let connection = strongSelf.movieFileOutput?.connection(withMediaType: AVMediaTypeVideo) {
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                }
                /*
                 Set Live Photo capture enabled if it is supported. When changing cameras, the
                 `isLivePhotoCaptureEnabled` property of the AVCapturePhotoOutput gets set to NO when
                 a video device is disconnected from the session. After the new video device is
                 added to the session, re-enable Live Photo capture on the AVCapturePhotoOutput if it is supported.
                 */
                //self.photoOutput.isLivePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureSupported;
                
                strongSelf.session.commitConfiguration()
            }
            catch {
                print("Error occured while creating video device input: \(error)")
            }
            
            if let device = strongSelf.videoDeviceInput?.device {
                do {
                    try device.lockForConfiguration()
                    device.isSubjectAreaChangeMonitoringEnabled = true
                    device.unlockForConfiguration()
                }
                catch {
                    print("Could not lock device for configuration: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                switch strongSelf.captureMode {
                case .stillImage:
                    endBlock(strongSelf.hasFlash)
                    break
                case .video(_, _, _):
                    endBlock(strongSelf.hasTorch)
                    break
                case .gif(_, _, _):
                    endBlock(strongSelf.hasTorch)
                    break
                }
                
            }
        }
    }
    
    // MARK: - Focus
    public func focus(with focusMode: AVCaptureFocusMode, exposureMode: AVCaptureExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool, showUI: @escaping ((Bool) -> ())) {
        
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            if let device = strongSelf.videoDeviceInput?.device {
                do {
                    try device.lockForConfiguration()
                    
                    DispatchQueue.main.async {
                        showUI( !(!device.isFocusPointOfInterestSupported && !device.isExposurePointOfInterestSupported) )
                    }

                    /*
                     Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                     Call set(Focus/Exposure)Mode() to apply the new point of interest.
                     */
                    if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                        device.focusPointOfInterest = devicePoint
                        device.focusMode = focusMode
                    }
                    
                    if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                        device.exposurePointOfInterest = devicePoint
                        device.exposureMode = exposureMode
                    }
                    
                    device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                    device.unlockForConfiguration()
                }
                catch {
                    print("Could not lock device for configuration: \(error)")
                }
            }
        }
    }
    
    // MARK: - Exposure
    public func expose(with exposureBias: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            if let device = strongSelf.videoDeviceInput?.device {
                do {
                    try device.lockForConfiguration()
                    device.setExposureTargetBias(Float(exposureBias), completionHandler: nil)
                    device.unlockForConfiguration()
                }
                catch {
                    print("Could not lock device for configuration: \(error)")
                }
            }
        }
    }
    
    // MARK: - Flash
    fileprivate func set(flashMode mode: AVCaptureFlashMode) {
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            if let device = strongSelf.videoDeviceInput?.device {
                do {
                    try device.lockForConfiguration()
                    
                    if device.hasFlash && device.isFlashModeSupported(mode) {
                        device.flashMode = mode
                    }
                    
                    device.unlockForConfiguration()
                }
                catch {
                    print("Could not lock device for configuration: \(error)")
                }
            }
        }
    }
    
    // MARK: - Torch
    fileprivate func set(torchMode mode: AVCaptureTorchMode) {
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            if let device = strongSelf.videoDeviceInput?.device {
                do {
                    try device.lockForConfiguration()
                    
                    if device.hasTorch && device.isTorchModeSupported(mode) {
                        device.torchMode = mode
                    }
                    
                    device.unlockForConfiguration()
                }
                catch {
                    print("Could not lock device for configuration: \(error)")
                }
            }
        }
    }
    
    // MARK: - Zoom
    public func set(zoomScale scale: CGFloat) {
        guard videoMaxZoomFactor > 1 else { return }
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            if let device = strongSelf.videoDeviceInput?.device {
                do {
                    try device.lockForConfiguration()
                    
                    device.videoZoomFactor = scale
                    strongSelf.currentZoomScale = scale
                    
                    device.unlockForConfiguration()
                }
                catch {
                    print("Could not lock device for configuration: \(error)")
                }
            }
        }
    }
    
    /**
     Adjust Zoom from UI.
     - Parameter percent:   The percentage of zoom scale.
     */
    public func adjust(zoomPercentage percent: CGFloat) {
        
    }
    
    // MARK: - KVO and Notifications
    fileprivate func addObservers() {
        //NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: AVCaptureDeviceSubjectAreaDidChangeNotification, object: videoDeviceInput.device)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        
        /*
         A session can only run when the app is full screen. It will be interrupted
         in a multi-app layout, introduced in iOS 9, see also the documentation of
         AVCaptureSessionInterruptionReason. Add observers to handle these session
         interruptions and show a preview is paused message. See the documentation
         of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
         */
        if #available(iOS 9.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
            NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
        }
    }
        
    fileprivate func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc fileprivate func subjectAreaDidChange(_ notification: Notification) {
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            let previewCenterPoint = CGPoint(x: strongSelf.previewView.bounds.width/2, y: strongSelf.previewView.bounds.height/2)
            let devicePoint = strongSelf.previewView.videoPreviewLayer.captureDevicePointOfInterest(for: previewCenterPoint)
            
            strongSelf.expose(with: 0)
            strongSelf.focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: true) { [weak strongSelf] showUI in
                if showUI {
                    strongSelf?.previewView.showFocusViewAtPoint(previewCenterPoint, dismiss: true)
                }
            }
        }
    }
        
    func sessionRuntimeError(_ notification: Notification) {
        guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
            return
        }
        
        let error = AVError(_nsError: errorValue)
        print("Capture session runtime error: \(error)")
        
        /*
         Automatically try to restart the session running if media services were
         reset and the last start running succeeded. Otherwise, enable the user
         to try to resume the session running.
         */
        if error.code == .mediaServicesWereReset {
            sessionQueue.async { [weak self] in
                guard let strongSelf = self else { return }
                
                if strongSelf.isSessionRunning {
                    strongSelf.session.startRunning()
                    strongSelf.isSessionRunning = strongSelf.session.isRunning
                }
                else {
                    // retry 5 seconds later
                    ScheduledTimer.schedule(5, block: { [weak strongSelf] _ in
                        strongSelf?.resumeInterruptedSession()
                    })
                }
            }
        }
        else {
            // retry 5 seconds later
            ScheduledTimer.schedule(5, block: { [weak self] _ in
                self?.resumeInterruptedSession()
            })
        }
    }
        
    func sessionWasInterrupted(_ notification: Notification) {
        /*
         In some scenarios we want to enable the user to resume the session running.
         For example, if music playback is initiated via control center while
         using AVCam, then the user can let AVCam resume
         the session running, which will stop music playback. Note that stopping
         music playback in control center will not automatically resume the session
         running. Also note that it is not always possible to resume, see `resumeInterruptedSession(_:)`.
         */
        if #available(iOS 9.0, *) {
            if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
                let reasonIntegerValue = userInfoValue.integerValue,
                let reason = AVCaptureSessionInterruptionReason(rawValue: reasonIntegerValue) {
                
                print("Capture session was interrupted with reason \(reason)")
                
                if reason == AVCaptureSessionInterruptionReason.audioDeviceInUseByAnotherClient || reason == AVCaptureSessionInterruptionReason.videoDeviceInUseByAnotherClient {
                    // retry 5 seconds later
                    ScheduledTimer.schedule(5, block: { [weak self] _ in
                        self?.resumeInterruptedSession()
                    })
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }
        
    func sessionInterruptionEnded(_ notification: Notification) {
        print("Capture session interruption ended")
    }
    
    fileprivate func resumeInterruptedSession() {
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            /*
             The session might fail to start running, e.g., if a phone or FaceTime call is still
             using audio or video. A failure to start the session running will be communicated via
             a session runtime error notification. To avoid repeatedly failing to start the session
             running, we only try to restart the session running in the session runtime error handler
             if we aren't trying to resume the session running.
             */
            strongSelf.session.startRunning()
            strongSelf.isSessionRunning = strongSelf.session.isRunning
            
            if !strongSelf.session.isRunning {
                
                /*
                DispatchQueue.main.async { [unowned self] in
                    let message = NSLocalizedString("Unable to resume", comment: "Alert message when unable to resume the session running")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    self.present(alertController, animated: true, completion: nil)
                }
                 */
            }
        }
    }
}

