//
//  ResultsViewController.swift
//  CaptureCenter
//
//  Created by Mingloan Chan on 7/21/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import UIKit
import Photos
import PhotosUI
import AVFoundation
import CaptureCenter

class ResultsViewController: UIViewController {
    
    var result = CaptureResult.stillImage(imageData: Data())
    
    convenience init(result: CaptureResult) {
        self.init(nibName: nil, bundle: nil)
        self.result = result
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        
        switch result {
        case .stillImage(let imageData):
            print("displaying still image captured")
            let imageView = UIImageView(image: UIImage(data: imageData))
            imageView.frame = CGRect(x: 0, y: 100, width: view.frame.width, height: view.frame.width)
            imageView.contentMode = .scaleAspectFit
            view.addSubview(imageView)
            break
        case .livePhoto(let livePhoto):
            print("displaying live photo captured")
            let livePhotoView = PHLivePhotoView(frame: CGRect(x: 0, y: 100, width: view.frame.width, height: view.frame.width))
            livePhotoView.contentMode = .scaleAspectFit
            livePhotoView.livePhoto = livePhoto
            view.addSubview(livePhotoView)
            break
        default:
            break
        }
    }
}
