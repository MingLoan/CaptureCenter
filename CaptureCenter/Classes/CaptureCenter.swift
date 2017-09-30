//
//  LiveCaptureCenter.swift
//
//  Created by Mingloan Chan on 29/4/2016.
//  Copyright © 2016. All rights reserved.
//

import Foundation
import AVFoundation

public final class CaptureCenter {
    
    // MARK: - Factory Methods
    static func getAVCaptureVideoOrientation(_ orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation? {
        switch orientation {
        case .portrait, .unknown:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        }
    }
    
    // get device for iOS9 or less
    fileprivate func deviceWithPosition(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        for device in AVCaptureDevice.devices() {
            if (device.hasMediaType(AVMediaType.video) && device.position == position) {
                return device
            }
        }
        return nil
    }
    
    // Public Properties
    public var hidesFocusControlUI = false
    public let previewView = PreviewView()
    public var currentFlashMode = AVCaptureDevice.FlashMode.off {
        didSet {
            if #available(iOS 10.0, *) {
                // deprecated from iOS10
            }
            else {
                setFlashMode(currentFlashMode)
            }
        }
    }
    public var currentTorchMode = AVCaptureDevice.TorchMode.off {
        didSet {
            setTorchMode(currentTorchMode)
        }
    }
    // value from 0 to 1
    var zoomPercentage: CGFloat = 0
    
    // Public Readonly Properties
    fileprivate(set) public var captureMode = CaptureMode.photo
    fileprivate(set) public var isSessionRunning = false
    fileprivate(set) public var hasFlash = false
    fileprivate(set) public var hasTorch = false
    fileprivate(set) public var videoMaxZoomFactor: CGFloat = 1
    fileprivate(set) public var currentZoomScale: CGFloat = 1 {
        didSet {
            DispatchQueue.main.async {
                if self.videoMaxZoomFactor > 1 {
                    self.zoomPercentage = (self.currentZoomScale - 1)/(self.videoMaxZoomFactor - 1)
                }
            }
        }
    }
    fileprivate(set) public var cameraControls = false
    
    // Private Properties
    fileprivate(set) var isSessionCongifured = false
    
    fileprivate enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    fileprivate let session = AVCaptureSession()
    fileprivate let sessionQueue = DispatchQueue(label: "session queue", attributes: [])
    fileprivate var setupResult: SessionSetupResult = .success
    
    // MARK: - CaptureDeviceInput
    fileprivate var videoDeviceInput: AVCaptureDeviceInput?
    internal var captureDevicePosition = AVCaptureDevice.Position.unspecified
    fileprivate var audioDeviceInput: AVCaptureDeviceInput?
    
    // MARK: - CaptureDeviceOutput
    // iOS 8, 9 Image Output
    fileprivate let imageOutput: AVCaptureStillImageOutput = {
        let stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        return stillImageOutput
    }()
    // iOS 10 Photo Output
    fileprivate var _photoOutput: AnyObject?
    fileprivate var inProgressPhotoCaptureDelegates = [Int64 : AnyObject]()
    @available(iOS 10.0, *)
    fileprivate var photoOutput: AVCapturePhotoOutput? {
        get {
            return _photoOutput as? AVCapturePhotoOutput
        }
        set {
            _photoOutput = newValue
        }
    }
    
    // Video Output
    fileprivate var movieFileOutput: AVCaptureMovieFileOutput?
    fileprivate var inProgressRecordingDelegate: MovieRecordingCaptureDelegate?
    //fileprivate var videoDataOutput: AVCaptureVideoDataOutput?
    fileprivate var backgroundRecordingID: UIBackgroundTaskIdentifier? = nil
    
    // Init
    public init(captureMode: CaptureMode) {
        self.captureMode = captureMode
    }
    
    // Deinit
    deinit {
        
    }
    
    // MARK: - Capture Methods
    @discardableResult
    public func startCapturingWithDevicePosition(_ devicePosition: AVCaptureDevice.Position, fromVC vc: UIViewController, cameraControlShouldOn: Bool = false, completion: ((Bool) -> ())? = nil) -> AVCaptureSession? {
        
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
                self?.configureSessionWithCaptureDevicePosition(devicePosition)
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
                DispatchQueue.main.async {
                    completion?(true)
                }
                break
            case .notAuthorized:
                DispatchQueue.main.async {
                    completion?(false)
                }
                break
            case .configurationFailed:
                DispatchQueue.main.async {
                    completion?(false)
                }
                break
            }
        }
        
        return session
    }
    
    public func stopCapturing() {
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.setupResult == .success {
                // return if session is not running
                guard strongSelf.isSessionRunning == true else { return }
                
                if let currentVideoDevice = strongSelf.videoDeviceInput?.device {
                    NotificationCenter.default.removeObserver(
                        strongSelf,
                        name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                        object: currentVideoDevice)
                }
                
                strongSelf.session.stopRunning()
                strongSelf.isSessionRunning = strongSelf.session.isRunning
                strongSelf.removeObservers()
                DispatchQueue.main.async {
                    strongSelf.previewView.videoPreviewLayer.contents = nil
                }
            }
        }
    }
    
    public func captureWithOptions(_ options: ImageOptions, completion: @escaping ((CaptureResult) -> ())) {
        
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            if #available(iOS 10.0, *) {
                /*
                 Retrieve the video preview layer's video orientation on the main queue before
                 entering the session queue. We do this to ensure UI elements are accessed on
                 the main thread and session configuration is done on the session queue.
                 */
                let videoPreviewLayerOrientation = strongSelf.previewView.videoPreviewLayer.connection?.videoOrientation
                
                // Update the photo output's connection to match the video orientation of the video preview layer.
                if let photoOutputConnection = strongSelf.photoOutput?.connection(with: AVMediaType.video) {
                    photoOutputConnection.videoOrientation = videoPreviewLayerOrientation!
                }
                
                let photoSettings = AVCapturePhotoSettings()
                photoSettings.flashMode = strongSelf.currentFlashMode
                if let photoOutput = strongSelf.photoOutput {
                    photoSettings.isAutoStillImageStabilizationEnabled = photoOutput.isStillImageStabilizationSupported
                }
                if case .highResolution = options.imageSize {
                    photoSettings.isHighResolutionPhotoEnabled = true
                }
                else {
                    photoSettings.isHighResolutionPhotoEnabled = false
                }
                
                if photoSettings.__availablePreviewPhotoPixelFormatTypes.count > 0 {
                    photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String : photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
                }
                
                // Live Photo capture is not supported in movie mode.
                if let photoOutput = strongSelf.photoOutput, options.imageType == .livePhoto && photoOutput.isLivePhotoCaptureEnabled {
                    let livePhotoMovieFileName = NSUUID().uuidString
                    let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
                    photoSettings.livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
                }
                /*
                if self.depthDataDeliveryMode == .on && self.photoOutput.isDepthDataDeliverySupported {
                    photoSettings.isDepthDataDeliveryEnabled = true
                } else {
                    photoSettings.isDepthDataDeliveryEnabled = false
                }
                */
                
                // Use a separate object for the photo capture delegate to isolate each capture life cycle.
                let photoCaptureDelegate =
                    PhotoCaptureDelegate(
                        with: photoSettings,
                        captureCenter: self,
                        imageOptions: options,
                        willCapturePhotoAnimation: { [weak strongSelf] in
                            DispatchQueue.main.async {
                                strongSelf?.previewView.videoPreviewLayer.opacity = 0
                                UIView.animate(withDuration: 0.25, animations: {
                                    strongSelf?.previewView.videoPreviewLayer.opacity = 1
                                })
                            }
                        }, livePhotoCaptureHandler: { started in
                            /*
                             Because Live Photo captures can overlap, we need to keep track of the
                             number of in progress Live Photo captures to ensure that the
                             Live Photo label stays visible during these captures.
                             */
                            /*
                            self.sessionQueue.async { [unowned self] in
                                if capturing {
                                    self.inProgressLivePhotoCapturesCount += 1
                                } else {
                                    self.inProgressLivePhotoCapturesCount -= 1
                                }
                                
                                let inProgressLivePhotoCapturesCount = self.inProgressLivePhotoCapturesCount
                                DispatchQueue.main.async { [unowned self] in
                                    if inProgressLivePhotoCapturesCount > 0 {
                                        self.capturingLivePhotoLabel.isHidden = false
                                    } else if inProgressLivePhotoCapturesCount == 0 {
                                        self.capturingLivePhotoLabel.isHidden = true
                                    } else {
                                        print("Error: In progress live photo capture count is less than 0")
                                    }
                                }
                            }*/
                        }, completionHandler: { [weak strongSelf] photoCaptureDelegate, result in
                            guard let innerStrongSelf = strongSelf else { return }
                            DispatchQueue.main.async {
                                completion(result)
                            }
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
                
                guard let videoConnection = strongSelf.imageOutput.connection(with: AVMediaType.video) else { return }
                
                strongSelf.imageOutput.captureStillImageAsynchronously(from: videoConnection) { [weak strongSelf] (sampleBuffer, error) in
                    
                    guard let innerStrongSelf = strongSelf else { return }
                    
                    if let _ = error {
                        completion(CaptureResult.empty)
                        return
                    }
                    
                    // for flash animation
//                    DispatchQueue.main.async {
//                        NotificationCenter.default.post(name: Notification.Name(rawValue: Global.Notification.liveFaceDidCaptureNotification), object: nil)
//                    }
                    
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer!)
                    let result = processCaptureData(imageData!, options: options, captureDevicePosition: innerStrongSelf.captureDevicePosition, previewViewSize: innerStrongSelf.previewView.bounds.size)
                    completion(result)
                }
            }
        }
    }
    
    public func toggleRecording() {
        guard let movieFileOutput = movieFileOutput else { return }
        
        /*
         Retrieve the video preview layer's video orientation on the main queue
         before entering the session queue. We do this to ensure UI elements are
         accessed on the main thread and session configuration is done on the session queue.
         */
        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection?.videoOrientation
        
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
                let movieFileOutputConnection = strongSelf.movieFileOutput?.connection(with: AVMediaType.video)
                movieFileOutputConnection?.videoOrientation = videoPreviewLayerOrientation!
                
                switch strongSelf.captureMode {
                case let .video(size, fileLocationURL, didStart, progress, willFinish, completionHandler):
                    let recordingDelegate =
                        MovieRecordingCaptureDelegate(size: size, didStart: didStart, progress: progress, willFinish: willFinish, completionHandler: completionHandler)
                    movieFileOutput.startRecording(to: fileLocationURL, recordingDelegate: recordingDelegate)
                    strongSelf.inProgressRecordingDelegate = recordingDelegate
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
    
    // MARK: - Configure Capture Session
    // Call this on the session queue.
    fileprivate func configureSessionWithCaptureDevicePosition(_ devicePosition: AVCaptureDevice.Position) {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        switch captureMode {
        case .photo:
            /*
             We do not create an AVCaptureMovieFileOutput when setting up the session because the
             AVCaptureMovieFileOutput does not support movie recording with AVCaptureSessionPresetPhoto.
             */
            session.sessionPreset = AVCaptureSession.Preset.photo
            break
        default:
            session.sessionPreset = AVCaptureSession.Preset.high
            break
        }
        
        // add video input
        var videoDevice: AVCaptureDevice?
        if devicePosition == .back {
            if #available(iOS 10.0, *) {
                if let dualCameraDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInDuoCamera, for: AVMediaType.video, position: .back) {
                    videoDevice = dualCameraDevice
                }
                else if let backCameraDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .back) {
                    // If the back dual camera is not available, default to the back wide angle camera.
                    videoDevice = backCameraDevice
                }
                else if let frontCameraDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .front) {
                    videoDevice = frontCameraDevice
                }
            }
            else {
                videoDevice = deviceWithPosition(devicePosition)
            }
        }
        else if devicePosition == .front {
            if #available(iOS 10.0, *) {
                videoDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: devicePosition)
            }
            else {
                videoDevice = deviceWithPosition(devicePosition)
            }
        }
        
        guard let device = videoDevice else { return }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: device)
            // videoMaxZoomFactor = device.activeFormat.videoMaxZoomFactor
            
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
        
        // add audio input
        do {
            let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)
            self.audioDeviceInput = audioDeviceInput
            
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            }
            else {
                print("Could not add audio device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
        catch {
            print("Could not create audio device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // add photo/image output
        if #available(iOS 10.0, *) {
            let output = AVCapturePhotoOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.isHighResolutionCaptureEnabled = true
                print("isLivePhotoCaptureSupported: \(output.isLivePhotoCaptureSupported)")
                output.isLivePhotoCaptureEnabled = output.isLivePhotoCaptureSupported
                // output.isDepthDataDeliveryEnabled = output.isDepthDataDeliverySupported
                photoOutput = output
            }
            else {
                print("Could not add photo output to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
        else {
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
        
        switch captureMode {
        case .video(let size, _, _, _, _, _):
            if !configureSessionForVideoMode(session, videoSize: size) {
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            break
        case .stream:
            break
        default:
            break
        }
        
        
        isSessionCongifured = true
        session.commitConfiguration()
        
        // device setups
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
    public func toggleCaptureMode(_ mode: CaptureMode, completion: @escaping ((Bool) -> ())) {
        
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            if strongSelf.captureMode == mode { return }
            
            strongSelf.captureMode = mode
            
            strongSelf.session.beginConfiguration()
            
            switch mode {
            case .photo:
                /*
                 Remove the AVCaptureMovieFileOutput from the session because movie recording is
                 not supported with AVCaptureSessionPresetPhoto. Additionally, Live Photo
                 capture is not supported when an AVCaptureMovieFileOutput is connected to the session.
                 */
                strongSelf.session.removeOutput(strongSelf.movieFileOutput!)
                // Remove movieFileOutput
                strongSelf.movieFileOutput = nil
                strongSelf.session.sessionPreset = AVCaptureSession.Preset.photo
                if #available(iOS 10.0, *) {
                    if let output = strongSelf.photoOutput {
                        output.isLivePhotoCaptureEnabled = output.isLivePhotoCaptureSupported
                    }
                }
                break
            case .video(let size, _, _, _, _, _):
                if !strongSelf.configureSessionForVideoMode(strongSelf.session, videoSize: size) {
                    print("toggle errer")
                }
                break
            case .stream:
                break
            }
            
            strongSelf.session.commitConfiguration()
            
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
    
    private func configureSessionForVideoMode(_ session: AVCaptureSession, videoSize: VideoSize) -> Bool {
        session.sessionPreset = AVCaptureSession.Preset.high

        let movieFileOutput = AVCaptureMovieFileOutput()
        switch videoSize {
        case .duration(let seconds):
            movieFileOutput.maxRecordedDuration = CMTime(seconds: seconds, preferredTimescale: 600)
            break
        case .fileSize(let bytes):
            movieFileOutput.maxRecordedFileSize = bytes
            break
        }
        
        //movieFileOutput.minFreeDiskSpaceLimit = ???
        movieFileOutput.movieFragmentInterval = kCMTimeInvalid
        
        if session.canAddOutput(movieFileOutput) {
            session.addOutput(movieFileOutput)
            session.sessionPreset = AVCaptureSession.Preset.medium
            
            if let connection = movieFileOutput.connection(with: AVMediaType.video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
            
            self.movieFileOutput = movieFileOutput
        }
        return true
    }
    
    // MARK: - Change Camera
    public func changeCameraWithStartBlock(_ startBlock: (() -> ()), finished endBlock: @escaping ((Bool) -> ())) {

        startBlock()

        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            let currentVideoDevice = strongSelf.videoDeviceInput?.device
            
            let currentPosition = currentVideoDevice?.position ?? .back
            var preferredPosition: AVCaptureDevice.Position
            
            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
                
            case .back:
                preferredPosition = .front
            }

            var videoDevice: AVCaptureDevice?
            
            if preferredPosition == .back {
                if #available(iOS 10.0, *) {
                    if let dualCameraDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInDuoCamera, for: AVMediaType.video, position: .back) {
                        videoDevice = dualCameraDevice
                    }
                    else if let backCameraDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .back) {
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
                    videoDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: preferredPosition)
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
                strongSelf.session.removeInput(strongSelf.videoDeviceInput!)
                
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
                    strongSelf.session.addInput(strongSelf.videoDeviceInput!);
                }
                
                if let connection = strongSelf.movieFileOutput?.connection(with: AVMediaType.video) {
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                }
                /*
                 Set Live Photo capture and depth data delivery if it is supported. When changing cameras, the
                 `livePhotoCaptureEnabled and depthDataDeliveryEnabled` properties of the AVCapturePhotoOutput gets set to NO when
                 a video device is disconnected from the session. After the new video device is
                 added to the session, re-enable them on the AVCapturePhotoOutput if it is supported.
                 */
                if #available(iOS 10.0, *) {
                    if let photoOutput = strongSelf.photoOutput {
                        photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
                        // photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
                    }
                }
                
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
                case .photo:
                    endBlock(strongSelf.hasFlash)
                    break
                case .video(_, _, _, _, _, _):
                    endBlock(strongSelf.hasTorch)
                    break
                case .stream:
                    break
                }
                
            }
        }
    }
    
    // MARK: - Focus
    public func focusWithMode(_ focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool, showUI: @escaping ((Bool) -> ())) {
        
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            if let device = strongSelf.videoDeviceInput?.device {
                do {
                    try device.lockForConfiguration()
                    
                    if !strongSelf.hidesFocusControlUI {
                        DispatchQueue.main.async {
                            showUI( !(!device.isFocusPointOfInterestSupported && !device.isExposurePointOfInterestSupported) )
                        }
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
    public func exposeWithBias(_ exposureBias: CGFloat) {
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
    fileprivate func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
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
    fileprivate func setTorchMode(_ mode: AVCaptureDevice.TorchMode) {
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
    public func setZoomScale(_ scale: CGFloat) {
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
    public func adjustZoomPercentage(_ percent: CGFloat) {
        
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
        
        let previewCenterPoint = CGPoint(x: previewView.bounds.width/2, y: previewView.bounds.height/2)
        let devicePoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: previewCenterPoint)
        
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.exposeWithBias(0)
            strongSelf.focusWithMode(.continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: true) { [weak strongSelf] showUI in
                if showUI {
                    strongSelf?.previewView.showFocusViewAtPoint(previewCenterPoint, dismiss: true)
                }
            }
        }
    }
        
    @objc func sessionRuntimeError(_ notification: Notification) {
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
        
    @objc func sessionWasInterrupted(_ notification: Notification) {
        /*
         In some scenarios we want to enable the user to resume the session running.
         For example, if music playback is initiated via control center while
         using AVCam, then the user can let AVCam resume
         the session running, which will stop music playback. Note that stopping
         music playback in control center will not automatically resume the session
         running. Also note that it is not always possible to resume, see `resumeInterruptedSession(_:)`.
         */
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
            let reasonIntegerValue = userInfoValue.integerValue,
            let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            
            print("Capture session was interrupted with reason \(reason)")
            
            if reason == AVCaptureSession.InterruptionReason.audioDeviceInUseByAnotherClient || reason == AVCaptureSession.InterruptionReason.videoDeviceInUseByAnotherClient {
                // retry 5 seconds later
                ScheduledTimer.schedule(5, block: { [weak self] _ in
                    self?.resumeInterruptedSession()
                })
            }
        }
    }
        
    @objc func sessionInterruptionEnded(_ notification: Notification) {
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

