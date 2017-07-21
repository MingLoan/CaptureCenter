//
//  CameraZoomSlider.swift
//  chaatz
//
//  Created by SHEILD on 8/9/2016.
//  Copyright © 2016 Chaatz. All rights reserved.
//

import Foundation
import UIKit

private extension UIImage {
    
    class func fillImg(withSize size: CGSize, color: UIColor) -> UIImage? {
        /* begin the graphic context */
        
        UIGraphicsBeginImageContext(size)
        color.set()
        UIRectFill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
}

@objc open class CameraZoomSlider: UISlider {
    var timer = Timer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        timer.invalidate()
    }
    
    func setup() {
        // Setup the zoom slider
        minimumValue = 1.0
        maximumValue = 1.0
        value = 1.0
        
        let thumbImage = UIImage.fillImg(withSize: CGSize(width: 4, height: 16), color: UIColor.yellow)
        let trackImage = UIImage.fillImg(withSize: CGSize(width: 1, height: 2), color: UIColor.white)
        
        setThumbImage(thumbImage, for: UIControlState())
        setMaximumTrackImage(trackImage, for: UIControlState())
        setMinimumTrackImage(trackImage, for: UIControlState())
        
        addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        
        alpha = 0.0
    }
    
    func valueChanged() {
        showSlider()
    }
    
    open override func setValue(_ value: Float, animated: Bool) {
        super.setValue(value, animated: animated)
        showSlider()
    }
    
    func showSlider() {
        timer.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(hideSlider), userInfo: nil, repeats: false)
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 1.0
        })
       
    }
    
    func hideSlider() {
        timer.invalidate()
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0.0
        })
    }
}
