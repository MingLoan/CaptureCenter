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

class ResultsViewController: UIViewController {
    
    enum ResultType {
        case stillImage(image: UIImage)
        //@available(iOS 9.1, *)
        case livePhoto(livePhoto: PHLivePhoto)
        case video(video: AVAsset)
    }
    
    var resultType = ResultType.stillImage(image: UIImage())
    
    convenience init(resultType: ResultType) {
        self.init(nibName: nil, bundle: nil)
        self.resultType = resultType
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        
        switch resultType {
        case .stillImage(let image):
            print("displaying still image captured")
            let imageView = UIImageView(image: image)
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
        case .video(let video):
            break
        }
    }
}
