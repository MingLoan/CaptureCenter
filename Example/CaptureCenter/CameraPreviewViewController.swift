//
//  CameraPreviewViewController.swift
//  CaptureCenter
//
//  Created by Mingloan Chan on 7/19/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import UIKit
import CaptureCenter

class CameraPreviewViewController: UIViewController {
    
    let captureCenter = CaptureCenter(captureMode: .photo)
    let captureButton = UIButton(type: .custom)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get preview view of capture center and set its frame
        captureCenter.previewView.frame = CGRect(x: 0, y: 64, width: view.frame.width, height: view.frame.width)
        view.addSubview(captureCenter.previewView)
        
        captureButton.setTitle("Capture Now", for: .normal)
        captureButton.setTitleColor(UIColor.blue, for: .normal)
        captureButton.frame = CGRect(x: 0, y: view.frame.width + 64 + 20, width: view.frame.width, height: 40)
        captureButton.addTarget(self, action: #selector(capture(_:)), for: .touchUpInside)
        view.addSubview(captureButton)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureCenter.stopCapturing()
    }
    
    @objc func capture(_ sender: UIButton) {
        if !captureCenter.isSessionRunning {
            captureCenter.startCapturingWithDevicePosition(
                .back,
                fromVC: self,
                cameraControlShouldOn: true) { [weak self] finished in
                    guard let strongSelf = self else { return }
                    if finished {
                        strongSelf.captureButton.setTitle("Stop Capture", for: .normal)
                    }
            }
        }
        else {
            captureCenter.stopCapturing()
            captureButton.setTitle("Capture Now", for: .normal)
        }
    }
}
