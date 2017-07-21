//
//  VideoMovieCaptureDelegate.swift
//  Pods
//
//  Created by Mingloan Chan on 7/21/17.
//
//

import Foundation
import AVFoundation

class MovieRecordingCaptureDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    
    fileprivate var videoSize: VideoSize
    fileprivate var didStart: (() -> ())?
    fileprivate var progress: ((CGFloat) -> ())?
    fileprivate var willFinish: (() -> ())?
    fileprivate var completionHandler: (AVAsset?) -> ()
    
    init(size: VideoSize,
         didStart: (() -> ())? = nil,
         progress: ((CGFloat) -> ())? = nil,
         willFinish: (() -> ())? = nil,
         completionHandler: @escaping (AVAsset?) -> ()) {
        self.videoSize = size
        self.didStart = didStart
        self.progress = progress
        self.willFinish = willFinish
        self.completionHandler = completionHandler
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        DispatchQueue.main.async {
            self.didStart?()
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    willFinishRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?){
        DispatchQueue.main.async {
            self.willFinish?()
        }
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        
        if let err = error {
            print("\(err)")
            if let finished = (error! as NSError).userInfo["AVErrorRecordingSuccessfullyFinishedKey"] as? Bool {
                if !finished {
                    return
                }
            }
        }
        
        let asset = AVAsset(url: outputFileURL)
        completionHandler(asset)
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didPauseRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]){
        
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didResumeRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]){
        
    }
}
