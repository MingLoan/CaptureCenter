//
//  LivePreviewView.swift
//
//  Created by Mingloan Chan on 29/4/2016.
//  Copyright © 2016. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

public class PreviewView: UIView {
    
    weak var captureCenter: CaptureCenter?
    
    public var canControlCamera = false {
        didSet {
            tapGesture.isEnabled = canControlCamera
            pinchGesture.isEnabled = canControlCamera
            panGesture.isEnabled = canControlCamera
        }
    }
    
    public var videoMaxZoomFactor: CGFloat = 1
    
    var focusTimer: ScheduledTimer?
    public var isFocusing = false
    
    fileprivate let focusView = CameraFocusView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
    fileprivate let exposureView = CameraExposureView(frame: CGRect(x: 0, y: 0, width: 22, height: 160))
    
    fileprivate var tapGesture: UITapGestureRecognizer!
    fileprivate var pinchGesture: UIPinchGestureRecognizer!
    fileprivate var panGesture: UIPanGestureRecognizer!
    
    override public class var layerClass : AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
//    override public var frame: CGRect {
//        didSet {
//            //print("\(frame)")
//            // disable implicit CAAnimation
//            CATransaction.begin()
//            CATransaction.setDisableActions(true)
//            //layer.frame = bounds
//            CATransaction.commit()
//        }
//    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
            videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black
        isUserInteractionEnabled = true
        focusView.alpha = 0
        exposureView.alpha = 0
        addSubview(focusView)
        addSubview(exposureView)
        
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        addGestureRecognizer(tapGesture)
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
        addGestureRecognizer(pinchGesture)
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        addGestureRecognizer(panGesture)
        
        tapGesture.isEnabled = false
        pinchGesture.isEnabled = false
        panGesture.isEnabled = false
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.orientationChanged(notification:)),
            name: Notification.Name.UIDeviceOrientationDidChange,
            object: nil
        )
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIDeviceOrientationDidChange, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    @objc func orientationChanged(notification: Notification) {
        // handle rotation here
        guard let connection = videoPreviewLayer.connection else { return }
        
        let interfaceOrientation: UIInterfaceOrientation = UIApplication.shared.statusBarOrientation
        
        let previewLayerConnection : AVCaptureConnection = connection
        
        if previewLayerConnection.isVideoOrientationSupported {
            if let newOrientation = CaptureCenter.getAVCaptureVideoOrientation(interfaceOrientation) {
                if newOrientation != previewLayerConnection.videoOrientation {
                    previewLayerConnection.videoOrientation = newOrientation
                }
            }
        }
    }
    
    // MARK: - Gestures Handling
    @objc func tap(_ gesture: UITapGestureRecognizer) {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else { return }
        guard let captureCenter = captureCenter else { return }
        
        let point = gesture.location(in: gesture.view)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        
        captureCenter.focusWithMode(.continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: true) { [weak self] showUI in
            if showUI {
                self?.showFocusViewAtPoint(point)
            }
        }
    }
    
    @objc func pan(_ gesture: UIPanGestureRecognizer) {

        guard let captureCenter = captureCenter else { return }
        if isFocusing {
            let velocity = gesture.velocity(in: gesture.view)
            
            switch gesture.state {
            case .changed:
                if fabs(velocity.y) > fabs(velocity.x) {
                    
                    var newExposure = exposureView.exposureBias + (velocity.y / bounds.size.height * -0.04)
                    if newExposure < -2.0 {
                        newExposure = -2.0
                    } else if (newExposure > 2.0) {
                        newExposure = 2.0
                    }
                    
                    captureCenter.exposeWithBias(newExposure)
                    setExposureBias(newExposure)
                }
                break
            default:
                break
            }
        }
    }
    
    fileprivate var startScale: CGFloat = 0
    fileprivate var startZoom: CGFloat = 0
    @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
        
        guard let captureCenter = captureCenter else { return }
        switch gesture.state {
        case .began:
            startZoom = captureCenter.currentZoomScale
            startScale = gesture.scale
            break
        case .changed:
            // print("gesture.scale \(gesture.scale)")
            let newScale = min(captureCenter.videoMaxZoomFactor, max(1.0, startZoom + (gesture.scale as CGFloat) - startScale))
            captureCenter.setZoomScale(newScale)
            break
        default:
            break
        }
    }
    
    func showFocusViewAtPoint(_ point: CGPoint, dismiss: Bool = false) {
        
        guard let captureCenter = captureCenter else { return }
        
        if let focusTimer = focusTimer {
            focusTimer.invalidate()
            self.focusTimer = nil
        }
    
        focusView.alpha = 0
        exposureView.alpha = 0.0
        exposureView.exposureBias = 0.0
        captureCenter.exposeWithBias(0.0)
        
        focusView.center = point
        if focusView.center.x + 70 > bounds.size.width {
            exposureView.center = CGPoint(x: focusView.center.x - 56, y: focusView.center.y)
        }
        else {
            exposureView.center = CGPoint(x: focusView.center.x + 56, y: focusView.center.y)
        }
        
        focusView.transform = CGAffineTransform.identity.scaledBy(x: 2.0, y: 2.0)
        
        UIView.animate(withDuration: 0.3, animations: {
            self.focusView.alpha = 1.0
            self.focusView.transform = CGAffineTransform.identity.scaledBy(x: 1.0, y: 1.0)
            }, completion: { _ in
                UIView.animate(withDuration: 0.3, animations: {
                    self.exposureView.alpha = 1.0
                }) 
            }) 
    
        if dismiss {
            ScheduledTimer.schedule(0.5, block: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.hideFocusAndExposureView()
            }, timerObject: { [weak self] (timer) in
                guard let strongSelf = self else { return }
                strongSelf.focusTimer = timer
            })
        }
        else {
            isFocusing = true
            ScheduledTimer.schedule(2, block: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.dimFocusAndExposureView()
            }, timerObject: { [weak self] (timer) in
                guard let strongSelf = self else { return }
                strongSelf.focusTimer = timer
            })
        }
        
    }
    
    func hideFocusAndExposureView() {
        if let focusTimer = focusTimer {
            isFocusing = false
            focusTimer.invalidate()
            self.focusTimer = nil
        }
        UIView.animate(withDuration: 0.2, animations: {
            self.focusView.alpha = 0.0
            self.exposureView.alpha = 0.0
        }) 
    }
    
    fileprivate func dimFocusAndExposureView() {
        if let focusTimer = focusTimer {
            focusTimer.invalidate()
        }
        UIView.animate(withDuration: 0.2, animations: {
            self.focusView.alpha = 0.3
            self.exposureView.alpha = 0.3
        }) 
    }
    
    fileprivate func brightFocusAndExposureView() {
        UIView.animate(withDuration: 0.2, animations: {
            self.focusView.alpha = 1
            self.exposureView.alpha = 1
        }) 
    }
    
    func setExposureBias(_ exposureBias: CGFloat) {
        if let focusTimer = focusTimer {
            focusTimer.invalidate()
        }

        exposureView.exposureBias = exposureBias
        
        brightFocusAndExposureView()
        ScheduledTimer.schedule(2, block: { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.dimFocusAndExposureView()
        }, timerObject: { [weak self] (timer) in
            guard let strongSelf = self else { return }
            strongSelf.focusTimer = timer
        })
    }
}
