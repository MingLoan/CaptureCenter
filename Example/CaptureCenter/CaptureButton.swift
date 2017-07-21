//
//  CaptureButton.swift
//  chaatz
//
//  Created by Mingloan Chan on 28/9/2016.
//  Copyright © 2016 Chaatz. All rights reserved.
//

import Foundation
import UIKit
import Cartography

enum CaptureButtonState {
    case photo
    case videoPlay
    case videoStop
}

private class CaptureButtonView: UIView {
    
    var state = CaptureButtonState.photo {
        didSet {
            if let layer = layer as? CAShapeLayer {
                switch state {
                case .photo:
                    layer.fillColor = UIColor.blue.cgColor
                    layer.path = drawPlay()
                    break
                case .videoPlay:
                    layer.fillColor = UIColor.red.cgColor
                    layer.path = drawPlay()
                    break
                case .videoStop:
                    layer.fillColor = UIColor.red.cgColor
                    layer.path = drawStop()
                    break
                }
            }
            setNeedsDisplay()
        }
    }

    override class var layerClass : AnyClass {
        return CAShapeLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        if let layer = layer as? CAShapeLayer {
            layer.lineCap = kCALineCapRound
            layer.lineWidth = 1
            layer.bounds = bounds
            layer.fillColor = UIColor.blue.cgColor
            layer.path = drawPlay()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let layer = layer as? CAShapeLayer {
            switch state {
            case .photo:
                layer.fillColor = UIColor.blue.cgColor
                layer.path = drawPlay()
                break
            case .videoPlay:
                layer.fillColor = UIColor.red.cgColor
                layer.path = drawPlay()
                break
            case .videoStop:
                layer.fillColor = UIColor.red.cgColor
                layer.path = drawStop()
                break
            }
        }
    }
    
    // Drawing Methods
    fileprivate func drawPlay() -> CGPath {
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: frame.width/2)
        return path.cgPath
    }
    
    fileprivate func drawStop() -> CGPath {
        let ratio: CGFloat = 0.6
        let sideSize = bounds.size.width * ratio
        
        let stopPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: sideSize, height: sideSize), cornerRadius: 5)        
        let delta = (bounds.size.width-sideSize)/2
        stopPath.apply(CGAffineTransform(translationX: delta, y: delta))
        return stopPath.cgPath
    }
}

class CaptureButton: UIButton {
    
    var captureButtonState = CaptureButtonState.photo {
        didSet {
            buttonView?.state = captureButtonState
        }
    }
    
    fileprivate var buttonView: CaptureButtonView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = frame.width/2
        layer.masksToBounds = true
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func commonInit() {
        buttonView = CaptureButtonView(frame: bounds)
        if let buttonView = buttonView {
            addSubview(buttonView)
            constrain(buttonView) { (targetView) in
                if let superview = targetView.superview {
                    targetView.edges == inset(superview.edges, 0)
                }
            }
        }
    }
    
}
