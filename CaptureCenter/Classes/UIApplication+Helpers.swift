//
//  UIApplication+Helpers.swift
//  Pods
//
//  Created by Mingloan Chan on 7/19/17.
//
//

import Foundation
import UIKit
import AVFoundation

extension UIApplication {
    /**
     Camera Permission
     - Parameter alertMessage:   The string to ask users to give permission.
     - Parameter deniedCancelClosure: The completion block if user cancelled dialog which asks for going to Settings.
     - Parameter fromViewController: The controller to present dialog.
     - Completion: The completion block for 1. granted, with 2. flag indicates first time asking
     */
    static func doesCameraAllowed(
        deniedAlert alertMessage: String,
        confirmationClosure: @escaping ((UIAlertAction) -> ()),
        fromViewController: UIViewController? = nil,
        completion:@escaping ((Bool, Bool) -> ())) {
        
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) { granted in
                
                completion(granted, true)
                
                if !granted {
                    
                    DispatchQueue.main.async {
                        let settings = UIAlertAction(title: "Change Settings", style: .default) { action in
                            confirmationClosure(action)
                            if let url = URL(string: UIApplicationOpenSettingsURLString) {
                                if #available(iOS 10.0, *) {
                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                } else {
                                    UIApplication.shared.openURL(url)
                                }
                            }
                        }
                        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { action in
                            confirmationClosure(action)
                        }
                        UIAlertController.presentAlertController(
                            title: "Camera Permissions Required",
                            message: alertMessage,
                            actions: [settings, cancel],
                            presentingViewController: fromViewController)
                    }
                }
            }
            break
        case .denied, .restricted:
            let settings = UIAlertAction(title: "Change Settings", style: .default) { action in
                confirmationClosure(action)
                if let url = URL(string: UIApplicationOpenSettingsURLString) {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    } else {
                        UIApplication.shared.openURL(url)
                    }
                }
            }
            let cancel = UIAlertAction(title: "Cancel", style: .cancel) { action in
                confirmationClosure(action)
            }
            
            UIAlertController.presentAlertController(
                title: "Camera Permissions Required",
                message: alertMessage,
                actions: [settings, cancel],
                presentingViewController: fromViewController)
            completion(false, false)
            break
        case .authorized:
            completion(true, false)
            break
        }
    }

}
