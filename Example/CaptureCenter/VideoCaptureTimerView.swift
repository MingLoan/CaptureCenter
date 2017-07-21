//
//  VideoCaptureTimerView.swift
//  chaatz
//
//  Created by Mingloan Chan on 27/9/2016.
//  Copyright © 2016 Chaatz. All rights reserved.
//

import Foundation
import UIKit
import Cartography
import AVFoundation

class VideoCaptureTimerView: UIView {
    
    fileprivate var isRecording = false {
        didSet {
            recordIndicatorView.isHidden = !isRecording
        }
    }

    fileprivate var recordTimer: ScheduledTimer?
    fileprivate var captureOutput: AVCaptureFileOutput?
    fileprivate let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [ .minute, .second ]
        formatter.zeroFormattingBehavior = [ .pad ]
        return formatter
    }()
    
    fileprivate let timerLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.text = "0:00"
        label.textColor = UIColor.white
        label.textAlignment = .center
        return label
    }()
    
    fileprivate let recordIndicatorView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 6, height: 6))
        view.backgroundColor = UIColor.red
        view.layer.cornerRadius = 3
        view.layer.masksToBounds = true
        view.isHidden = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func commonInit() {
        isUserInteractionEnabled = false
        backgroundColor = UIColor.black.withAlphaComponent(0.4)
        layer.cornerRadius = 3
        layer.masksToBounds = true
        
        addSubview(timerLabel)
        addSubview(recordIndicatorView)
        constrain(timerLabel, recordIndicatorView) { (timerLabelRef, recordIndicatorViewRef) in
            if let superview = timerLabelRef.superview {
                timerLabelRef.edges == inset(superview.edges, 0)
                recordIndicatorViewRef.left == superview.left + 10
            }
            recordIndicatorViewRef.centerY == timerLabelRef.centerY
            recordIndicatorViewRef.width == 6
            recordIndicatorViewRef.height == 6
        }
    }
    
    func reset() {
        timerLabel.text = "0:00"
    }
    
    func startRecording(withCaptureOutput captureOutput: AVCaptureFileOutput) {
        if !isRecording {
            isRecording = true
            self.captureOutput = captureOutput
            startTimer()
        }
    }
    
    func endRecording() {
        if isRecording {
            isRecording = false
            recordTimer?.invalidate()
            recordTimer = nil
            timerLabel.text = "0:00"
        }
    }
    
    fileprivate func startTimer() {
        recordTimer?.invalidate()
        recordTimer = nil
        
        ScheduledTimer.schedule(every: 0.2, block: { [weak self] (timer) in
            
            guard let strongSelf = self, let captureOutput = strongSelf.captureOutput else { return }

            let currentDuration = CMTimeGetSeconds(captureOutput.recordedDuration)
            
            if currentDuration > 0 {
                let formattedDuration = strongSelf.durationFormatter.string(from: ceil(currentDuration))
                strongSelf.timerLabel.text = formattedDuration
            }
            else {
                strongSelf.timerLabel.text = "0:00"
            }
        }, timerObject: { [weak self] (timer) in
            guard let strongSelf = self else { return }
            strongSelf.recordTimer = timer
        })
    }
    
}
