//
//  CameraViewController.swift
//
//  Created by Mingloan Chan on 6/9/2016.
//  Copyright © 2016. All rights reserved.
//

import Foundation
import UIKit
import CaptureCenter

private final class CameraPreviewContainerView: UIView {
    
    fileprivate weak var previewView: UIView?
    
    convenience init() {
        self.init(frame: CGRect.zero)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func commonInit() {
        backgroundColor = UIColor.clear
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewView?.frame = bounds
    }
    
    func screenShotFlash(_ completion: (() -> ())?) {
        
        let aView = UIView(frame: bounds)
        aView.backgroundColor = UIColor.white
        addSubview(aView)
        
        UIView.animate(
            withDuration: 1,
            delay: 0,
            options: UIViewAnimationOptions(),
            animations: {
                aView.alpha = 0.0
        }) { _ in
            aView.removeFromSuperview()
            completion?()
        }
    }
}

extension CameraPreviewContainerView: CapturePreview {
    
    func attachPreviewView(_ previewView: UIView) {
        previewView.frame = bounds
        previewView.alpha = 0
        self.previewView = previewView
        addSubview(previewView)
        UIView.animate(withDuration: 0.2, animations: {
            self.previewView?.alpha = 1
        }) 
    }
    
    func detachPreviewView() {
        UIView.animate(withDuration: 0.2, animations: {
            self.previewView?.alpha = 0
        }, completion: { (finished) in
            self.previewView?.removeFromSuperview()
        }) 
    }
    
}

class CameraViewController: UIViewController {
    
    fileprivate var isSquared = false
    fileprivate var canCaptureVideo = true
    
    // control recording
    fileprivate var capturingVideo = false {
        didSet {
            if capturingVideo {
                UIApplication.shared.isIdleTimerDisabled = true
                captureButton.captureButtonState = .videoStop
            }
            else {
                UIApplication.shared.isIdleTimerDisabled = false
                captureButton.captureButtonState = .videoPlay
            }
            
            captureCenter?.toggleRecording()
            
            UIView.animate(withDuration: 0.2, animations: {
                if self.capturingVideo {
                    self.photoVideoToggleButton.alpha = 0
                }
                else {
                    self.photoVideoToggleButton.alpha = 1
                }
            }) 
        }
    }
    fileprivate var capturingGIF = false {
        didSet {
            if capturingGIF {
                UIApplication.shared.isIdleTimerDisabled = true
                captureButton.captureButtonState = .videoStop
            }
            else {
                UIApplication.shared.isIdleTimerDisabled = false
                captureButton.captureButtonState = .videoPlay
            }
            
            captureCenter?.toggleRecording()
            
            UIView.animate(withDuration: 0.2, animations: {
                if self.capturingVideo {
                    self.photoVideoToggleButton.alpha = 0
                }
                else {
                    self.photoVideoToggleButton.alpha = 1
                }
            }) 
        }
    }
    
    // Camera
    fileprivate(set) var captureCenter: CaptureCenter?
    fileprivate let previewContainerView = CameraPreviewContainerView()
    fileprivate var captureSessionDidStartRunningNotification: NSObjectProtocol?

    var captured: ((Data) -> ()) = { _ in }
    
//    fileprivate let zoomSlider: CameraZoomSlider = {
//        let slider = CameraZoomSlider()
//        slider.isContinuous = true
//        return slider
//    }()
    
    fileprivate let cameraSwitchButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = UIColor.white
        button.setImage(UIImage(named:"back-camera-icon"), for: UIControlState())
        return button
    }()
    
    fileprivate let gifSwitchButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = UIColor.white
        button.setImage(UIImage(named:"battleship_icon"), for: UIControlState())
        return button
    }()
    
    fileprivate let flashButton: UIButton = {
        let button = UIButton(type: .custom)
        return button
    }()

    fileprivate let captureProgressRingView = CaptureProgressRingView(frame: CGRect(x: 0, y: 0, width: 74, height: 74))
    
    fileprivate let bottomView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        return view
    }()
    
    fileprivate let captureButton: CaptureButton = {
        let button = CaptureButton(type: .custom)
        button.setTitle("", for: UIControlState())
        button.tintColor = UIColor.white
        button.layer.cornerRadius = 30
        button.layer.masksToBounds = true
        return button
    }()
    
    fileprivate let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named:"close-icon-camera"), for: UIControlState())
        button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        button.tintColor = UIColor.white
        return button
    }()
    
    fileprivate let photoVideoToggleButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("", for: UIControlState())
        button.tintColor = UIColor.white
        button.setImage(UIImage(named: "chess_icon"), for: UIControlState())
        return button
    }()

    fileprivate let timerView: VideoCaptureTimerView = {
        let view = VideoCaptureTimerView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        view.isHidden = true
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isTranslucent = false
        view.backgroundColor = UIColor.normalBlackColor()
        
        view.addSubview(previewContainerView)
        
        view.addSubview(bottomView)
        constrain(bottomView){ (targetView) in
            if let superview = targetView.superview {
                targetView.bottom == superview.bottom
                targetView.right == superview.right
                targetView.left == superview.left
            }
            targetView.height == 80
        }
        
        // Flash button
        flashButton.addTarget(self, action: #selector(flashButtonTapped(_:)), for: .touchUpInside)
        view.addSubview(flashButton)
        constrain(flashButton){ (targetView) in
            if let superview = targetView.superview {
                targetView.top == superview.top + 10
                targetView.right == superview.right - 10
            }
            targetView.width == 80
            targetView.height == 40
        }
        
        
        // Capture button
        captureButton.addTarget(self, action: #selector(capture(_:)), for: .touchUpInside)
        
        bottomView.addSubview(captureProgressRingView)
        
        // Camera button
        cameraSwitchButton.addTarget(self, action: #selector(cameraDeviceToggle(_:)), for: .touchUpInside)
        bottomView.addSubview(cameraSwitchButton)
        constrain(cameraSwitchButton){ (targetView) in
            if let superview = targetView.superview {
                targetView.bottom == superview.bottom - 10
                targetView.right == superview.right - 10
            }
            targetView.width == 40
            targetView.height == 40
        }
        
        // GIF button
        /*
        gifSwitchButton.addTarget(self, action: #selector(gifToggle(_:)), for: .touchUpInside)
        bottomView.addSubview(gifSwitchButton)
        constrain(gifSwitchButton){ (targetView) in
            if let superview = targetView.superview {
                targetView.bottom == superview.bottom - 10
                targetView.right == superview.right - 70
            }
            targetView.width == 40
            targetView.height == 40
        }
        */
        bottomView.addSubview(captureButton)
        constrain(captureButton, captureProgressRingView) { (captureButton, captureProgressRingView) in
            if let superview = captureButton.superview {
                captureButton.center == superview.center
                captureProgressRingView.center == superview.center
            }
            captureProgressRingView.width == 74
            captureProgressRingView.height == 74
            
            captureButton.width == 60
            captureButton.height == 60
        }
        
        
        if let source = mediaSource {
            switch source.sourceType {
            case .camera:
                photoVideoToggleButton.addTarget(self, action: #selector(photoVideoToggle(_:)), for: .touchUpInside)
                bottomView.addSubview(photoVideoToggleButton)
                constrain(photoVideoToggleButton) { (targetView) in
                    if let superview = targetView.superview {
                        targetView.left == superview.left + 10
                        targetView.bottom == superview.bottom - 10
                    }
                    targetView.width == 50
                    targetView.height == 50
                }
                break
            default:
                break
            }
        }
        
        // Close button
        closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        view.addSubview(closeButton)
        constrain(closeButton) { (targetView) in
            if let superview = targetView.superview {
                targetView.top == superview.top + 10
                targetView.left == superview.left + 10
            }
            targetView.width == 40
            targetView.height == 40
        }
        /*
        // Zoom slider
        zoomSlider.addTarget(self, action: #selector(zoomSliderChanged(_:)), forControlEvents: .ValueChanged)
        view.addSubview(zoomSlider)
        constrain(zoomSlider) { (targetView) in
            if let superview = targetView.superview {
                targetView.left == superview.left + 16
                targetView.right == superview.right - 16
            }
            targetView.height == 40
        }
        constrain(zoomSlider, previewView) { (zoomSlider, previewView) -> () in
            zoomSlider.bottom == previewView.bottom - 88
        }
        
        // Setup the control view
        zoomScale = CGFloat(zoomSlider.value)
        redrawFlashButton()
        */
        // Timer Label
        view.addSubview(timerView)
        constrain(timerView) { (targetView) in
            if let superview = targetView.superview {
                targetView.centerX == superview.centerX
                targetView.top == superview.top + 10
            }
            targetView.height == 30
            targetView.width == 120
        }
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if isSquared {
            previewContainerView.frame = CGRect(x: 0, y: (view.frame.height - view.frame.width)/2, width: view.frame.width, height: view.frame.width)
            previewContainerView.center = view.center
        }
        else {
            previewContainerView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        startCapturing()
    }
    
    // MARK: - Live
    func startCapturing() {
        
        if captureCenter == nil {
            captureCenter = CaptureCenter()
        }
        
        captureSessionDidStartRunningNotification =
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name.AVCaptureSessionDidStartRunning,
                object: nil,
                queue: OperationQueue.main) { [weak self] (_) in
                    self?.redrawFlashButton()
        }
        _ = captureCenter?.startCapturing(.back, from: self, cameraControlShouldOn: true)
        
        if let previewView = captureCenter?.previewView {
            previewContainerView.attachPreviewView(previewView)
        }
    }
    
    func stopCapturing() {
        guard let captureCenter = captureCenter else { return }
        NotificationCenter.default.removeOptionalObserver(captureSessionDidStartRunningNotification)
        captureCenter.stopCapturing()
        previewContainerView.detachPreviewView()
    }
    
    func close(_ sender: UIButton) {
        if capturingVideo {
            capturingVideo = false
        }
        if capturingGIF {
            capturingGIF = false
        }
        stopCapturing()
        showStatusBar()
        dismiss(animated: true, completion: nil)
    }
    
    func capture(_ sender: UIButton) {
        
        guard let captureCenter = captureCenter else { return }

        switch captureCenter.captureMode {
        case .stillImage:
            
            UIApplication.shared.beginIgnoringInteractionEvents()
            
            captureCenter.capture(.fullScreen) { [unowned self] data in
                // upload image and send
                guard let imageData = data, let img = UIImage(data: imageData) else { return }
                
                DispatchQueue.main.async {
                    UIApplication.shared.endIgnoringInteractionEvents()
                    let editViewController = MediaEditViewController(nibName: nil, bundle: nil)
                    editViewController.mediaSource = self.mediaSource
                    editViewController.medias = [Media.image(image: img)]
                    self.navigationController?.pushViewController(editViewController, animated: true)
                }
            }

            break
        case .video(_, _, _):
            capturingVideo = !capturingVideo
            break
        case .gif(_, _, _):
            capturingGIF = !capturingGIF
            break
        }
    }
    
    // MARK: - Toggle Photo Capture and Video Taking
    func photoVideoToggle(_ sender: UIButton) {
        
        guard let captureCenter = captureCenter else { return }
        
        captureButton.isEnabled = false
        
        switch captureCenter.captureMode {
        case .stillImage:
            
            captureCenter.toggle(
                captureMode:
                    .video(size: .fileSize(bytes: 5 * 1024 * 1024),
                        location: tempURLForVideo(),
                        delegateObject: self))
            { [unowned self] finished in
                self.captureButton.isEnabled = true
            }
            timerView.reset()
            timerView.isHidden = false
            captureButton.captureButtonState = .videoPlay
            
            break
        case .video(_, _, _), .gif(_):
            captureCenter.toggle(captureMode: .stillImage) { [unowned self] finished in
                self.captureButton.isEnabled = true
            }
            timerView.isHidden = true
            captureButton.captureButtonState = .photo
            photoVideoToggleButton.setImage(UIImage(named: "chess_icon"), for: UIControlState())
            break
        }
    }
    
    // MARK: - Toggle to GIF mode
    func gifToggle(_ sender: UIButton) {
        guard let captureCenter = captureCenter else { return }
        
        captureButton.isEnabled = false
        
        switch captureCenter.captureMode {
        case .stillImage, .video(_, _, _):
            
            captureCenter.toggle(
                captureMode:
                    .gif(size: .duration(timeInterval: 5),
                        location: tempURLForVideo(),
                        delegateObject: self))
            { [unowned self] finished in
                self.captureButton.isEnabled = true
            }
            timerView.reset()
            timerView.isHidden = true
            captureButton.captureButtonState = .videoPlay
            
            break
        default:
            break
        }
    }
    
    // MARK: - Toggle front or back camera
    func cameraDeviceToggle(_ sender: UIButton) {
        
        guard let captureCenter = captureCenter else { return }
        
        captureCenter.changeCamera(start: { [weak self] in
            self?.cameraSwitchButton.isEnabled = false
            self?.captureButton.isEnabled = false
            self?.flashButton.isEnabled = false
        }, finished: { [weak self] _ in
            self?.cameraSwitchButton.isEnabled = true
            self?.captureButton.isEnabled = true
            self?.flashButton.isEnabled = true
            self?.redrawFlashButton()
        })
    }

    /*
    func zoomSliderChanged(sender: UISlider) {
        zoomScale = CGFloat(sender.value)
        setZoomScale()
    }
    
    func setZoomScale() {
        do {
            guard let device = currentCameraInput?.device else { return }
            try device.lockForConfiguration()
            device.videoZoomFactor = zoomScale
            device.unlockForConfiguration()
            previewView.hideFocusAndExposureView()
        }
        catch {
            debug_print("\(error)")
        }
    }
    */
    // MARK: - Flash Button
    fileprivate func redrawFlashButton() {
        
        guard let captureCenter = captureCenter else { return }
        
        switch captureCenter.captureMode {
        case .stillImage:
            
            guard captureCenter.hasFlash else {
                flashButton.isHidden = true
                return
            }
            flashButton.isHidden = false
            switch captureCenter.currentFlashMode {
            case .auto:
                flashButton.tintColor = UIColor.yellow
                flashButton.setTitle(" Auto", for: UIControlState())
                flashButton.setTitleColor(UIColor.yellow, for: UIControlState())
                flashButton.setImage(UIImage(named: "1093-lightning-bolt-2-toolbar-selected")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
                break
            case .off:
                flashButton.tintColor = UIColor(white: 0.8, alpha: 1.0)
                flashButton.setTitle(" Off", for: UIControlState())
                flashButton.setTitleColor(UIColor(white: 0.8, alpha: 1.0), for: UIControlState())
                flashButton.setImage(UIImage(named: "1093-lightning-bolt-2-toolbar-selected")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
                break
            case .on:
                flashButton.tintColor = UIColor.white
                flashButton.setTitle(" On", for: UIControlState())
                flashButton.setTitleColor(UIColor.white, for: UIControlState())
                flashButton.setImage(UIImage(named: "1093-lightning-bolt-2-toolbar-selected")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
                break
            }
            
            break
        case .video(_), .gif(_):
            
            guard captureCenter.hasTorch else {
                flashButton.isHidden = true
                return
            }
            flashButton.isHidden = false
            switch captureCenter.currentTorchMode {
            case .off:
                flashButton.tintColor = UIColor(white: 0.8, alpha: 1.0)
                flashButton.setTitle(" Off", for: UIControlState())
                flashButton.setTitleColor(UIColor(white: 0.8, alpha: 1.0), for: UIControlState())
                flashButton.setImage(UIImage(named: "1093-lightning-bolt-2-toolbar-selected")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
                break
            case .on:
                flashButton.tintColor = UIColor.white
                flashButton.setTitle(" On", for: UIControlState())
                flashButton.setTitleColor(UIColor.white, for: UIControlState())
                flashButton.setImage(UIImage(named: "1093-lightning-bolt-2-toolbar-selected")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
                break
            case .auto:
                flashButton.tintColor = UIColor.yellow
                flashButton.setTitle(" Auto", for: UIControlState())
                flashButton.setTitleColor(UIColor.yellow, for: UIControlState())
                flashButton.setImage(UIImage(named: "1093-lightning-bolt-2-toolbar-selected")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
                break
            }
            break
        }
        
        
    }
    
    func flashButtonTapped(_ sender: UIButton) {
        
        guard let captureCenter = captureCenter else { return }
        
        switch captureCenter.captureMode {
        case .stillImage:
            
            switch captureCenter.currentFlashMode {
            case .auto:
                captureCenter.currentFlashMode = .off
                break
            case .off:
                captureCenter.currentFlashMode = .on
                break
            case .on:
                captureCenter.currentFlashMode = .auto
                break
            }
            redrawFlashButton()
            
            break
        case .video(_):
            
            switch captureCenter.currentTorchMode {
            case .off:
                captureCenter.currentTorchMode = .on
                break
            case .on:
                captureCenter.currentTorchMode = .auto
                break
            case .auto:
                captureCenter.currentTorchMode = .off
                break
            }
            
            redrawFlashButton()
            break
        default:
            break
        }
    }
    // MARK: - Video Recording
    fileprivate func tempURLForVideo() -> URL {
        let path = filePath(with: .mp4, sid: "temp", fileName: "temp")
        if let path = path {
            removeFile(at: path)
        }
        let url = URL(fileURLWithPath: path!)
        return url
    }
}

extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {

        DispatchQueue.main.async {
            
            self.cameraSwitchButton.isHidden = true
            
            if self.capturingVideo {
                self.timerView.startRecording(withCaptureOutput: captureOutput)
                self.captureProgressRingView.startRecording(withCaptureOutput: captureOutput)
            }
            else {
                self.flashButton.isHidden = true
            }
        }
    }

    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        pretty_function()
        
        DispatchQueue.main.async {
            
            self.cameraSwitchButton.isHidden = false
            
            if self.capturingVideo {
                self.timerView.endRecording()
                self.captureProgressRingView.endRecording()
            }
            else {
                self.flashButton.isHidden = false
            }
        }
        
        
        if let err = error {
            debug_print("\(err)")
            if let finished = (error! as NSError).userInfo["AVErrorRecordingSuccessfullyFinishedKey"] as? Bool {
                if !finished {
                    return
                }
            }
        }
        
        let asset = AVAsset(url: outputFileURL)
        DispatchQueue.main.async {
            
            UIApplication.shared.beginIgnoringInteractionEvents()
            
            if self.capturingVideo {
                let editViewController = MediaEditViewController(nibName: nil, bundle: nil)
                editViewController.mediaSource = self.mediaSource
                editViewController.medias = [Media.videoAsset(asset: asset)]
                self.navigationController?.pushViewController(editViewController, animated: true)
                UIApplication.shared.endIgnoringInteractionEvents()
            }
            else {
                /*
                let frameCount = Int(CMTimeGetSeconds(asset.duration) * 10)
                
                Regift.createGIFFromSource(
                    outputFileURL,
                    frameCount: frameCount,
                    delayTime: 0,
                    loopCount: 1) { resultURL in
                        guard let url = resultURL else { return }
                        guard let data = NSData(contentsOfURL: url) else { return }

                        //let thumbnailImage = UIImageWithAnimatedGIFData(data)
                        
                        debug_print("\(url)")
                        guard NSThread.isMainThread() else { return }
                        
                        let media = Media.gif(data: data, thumbnail: nil)
                        
                        let previewViewController = GIFPreviewViewController(nibName: nil, bundle: nil)
                        previewViewController.gif = media
                        previewViewController.mediaSource = self.mediaSource
                        self.navigationController?.pushViewController(previewViewController, animated: true)
                        UIApplication.sharedApplication().endIgnoringInteractionEvents()
                        UIApplication.sharedApplication().endIgnoringInteractionEvents()
                    }
                 */
            }
        }
    }
}
