//
//  CaptureProgressRingView.swift
//  chaatz
//
//  Created by Mingloan Chan on 28/9/2016.
//  Copyright © 2016 Chaatz. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

private class ProgressRingView: UIView {
    
    override class var layerClass : AnyClass {
        return CAShapeLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        if let layer = layer as? CAShapeLayer {
            layer.lineCap = kCALineCapRound
            layer.lineWidth = 4
            layer.bounds = bounds
            layer.strokeColor = UIColor.red.cgColor
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeStart = 0
            layer.strokeEnd = 0
            layer.path = drawTrack()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let layer = layer as? CAShapeLayer {
            layer.path = drawTrack()
        }
    }
    
    // Drawing Methods
    fileprivate func drawTrack() -> CGPath {
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: frame.width/2)
        return path.cgPath
    }
    
    func set(progress p: CGFloat) {
        if let layer = layer as? CAShapeLayer {
            layer.strokeEnd = p
        }
    }
}

class CaptureProgressRingView: UIView {

    fileprivate var recordTimer: ScheduledTimer?
    fileprivate var captureOutput: AVCaptureFileOutput?

    fileprivate let progressView = ProgressRingView(frame: CGRect.zero)
    
    override class var layerClass : AnyClass {
        return CAShapeLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        if let layer = layer as? CAShapeLayer {
            layer.lineCap = kCALineCapRound
            layer.lineWidth = 4
            layer.bounds = bounds
            layer.strokeColor = UIColor.white.cgColor
            layer.fillColor = nil
            layer.path = drawTrack()
        }
        progressView.frame = bounds
        addSubview(progressView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        progressView.frame = bounds
        if let layer = layer as? CAShapeLayer {
            layer.path = drawTrack()
        }
    }
    
    // Drawing Methods
    fileprivate func drawTrack() -> CGPath {
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: frame.width/2)
        return path.cgPath
    }

    func startRecording(withCaptureOutput captureOutput: AVCaptureFileOutput) {
        self.captureOutput = captureOutput
        startTimer()
    }
    
    func endRecording() {
        recordTimer?.invalidate()
        recordTimer = nil
        progressView.set(progress: 0)
    }
    
    fileprivate func startTimer() {
        recordTimer?.invalidate()
        recordTimer = nil
        
        ScheduledTimer.schedule(every: 0.2, block: { [weak self] (timer) in
            
            guard let strongSelf = self, let captureOutput = strongSelf.captureOutput else { return }

            debug_print("\(captureOutput.recordedFileSize)")
            debug_print("\(captureOutput.maxRecordedFileSize)")
            if captureOutput.maxRecordedFileSize > 0 {
                let progress = max(0, min(CGFloat(captureOutput.recordedFileSize)/CGFloat(captureOutput.maxRecordedFileSize), 1))
                debug_print("\(progress)")
                strongSelf.progressView.set(progress: progress)
            }
            else {
                strongSelf.progressView.set(progress: 0)
            }
        }, timerObject: { [weak self] (timer) in
            guard let strongSelf = self else { return }
            strongSelf.recordTimer = timer
        })
    }
}
