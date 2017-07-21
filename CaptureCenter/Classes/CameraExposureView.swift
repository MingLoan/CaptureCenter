//
//  CameraExposureView.swift
//  chaatz
//
//  Created by SHEILD on 8/9/2016.
//  Copyright © 2016 Chaatz. All rights reserved.
//

import Foundation

@objc open class CameraExposureView: UIView {
    var icon: UIImage? = nil
    
    var exposureBias: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        icon = ipMaskedImageNamed("ic_brightness", color: UIColor.yellow)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func ipMaskedImageNamed(_ name: String, color: UIColor) -> (UIImage?) {
        let podBundle = Bundle(for: CameraExposureView.self)
        guard
            let bundleURL = podBundle.url(forResource: "CaptureCenter", withExtension: "bundle"),
            let bundle = Bundle(url: bundleURL),
            let image = UIImage(named: name, in: bundle, compatibleWith: nil) else {
                return nil
        }
        
        let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, image.scale)
        let c = UIGraphicsGetCurrentContext()
        image.draw(in: rect)
        c!.setFillColor(color.cgColor)
        c!.setBlendMode(.sourceAtop)
        c!.fill(rect)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    override open func draw(_ rect: CGRect) {
        let lineMargin: CGFloat = 11.0
        let lineHeight: CGFloat = 160.0-22.0
    
        // Drawing code
        let context = UIGraphicsGetCurrentContext()
    
        context!.setStrokeColor(UIColor.yellow.cgColor)
        context!.setLineWidth(1)
    
        if (alpha > 0.0) {
            context!.move(to: CGPoint(x: rect.size.width/2, y: lineMargin));
            context!.addLine(to: CGPoint(x: rect.size.width/2, y: lineMargin+lineHeight));
            UIGraphicsGetCurrentContext()!.strokePath()
        }
    
        let y = (lineHeight / 2) - (self.exposureBias / 2 * lineHeight / 2)
        if let icon = icon {
            context!.draw(icon.cgImage!, in: CGRect(x: 0, y: y, width: 22, height: 22))
        }
    }
}
