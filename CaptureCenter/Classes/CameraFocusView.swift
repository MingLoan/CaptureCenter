//
//  CameraFocusView.swift
//  chaatz
//
//  Created by SHEILD on 8/9/2016.
//  Copyright © 2016 Chaatz. All rights reserved.
//

import Foundation

@objc open class CameraFocusView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override func draw(_ rect: CGRect) {
        // Drawing code
        let context = UIGraphicsGetCurrentContext()
        
        context!.setStrokeColor(UIColor.yellow.cgColor)
        context!.setLineWidth(2)
        
        // Draw the window 'frame'
        context!.stroke(CGRect.init(x: 0, y: 0, width: rect.size.width, height: rect.size.height))
        
        // Draw 8 touch points
        context!.move(to: CGPoint(x: 0, y: rect.size.height/2))
        context!.addLine(to: CGPoint(x: 8, y: rect.size.height/2))
        
        context!.move(to: CGPoint(x: rect.size.width-1, y: rect.size.height/2))
        context!.addLine(to: CGPoint(x: rect.size.width-9, y: rect.size.height/2))
        
        context!.move(to: CGPoint(x: rect.size.width/2, y: 0))
        context!.addLine(to: CGPoint(x: rect.size.width/2, y: 8))
        
        context!.move(to: CGPoint(x: rect.size.width/2, y: rect.size.height-1))
        context!.addLine(to: CGPoint(x: rect.size.width/2, y: rect.size.height-9))
        
        UIGraphicsGetCurrentContext()!.strokePath()
    }
}
