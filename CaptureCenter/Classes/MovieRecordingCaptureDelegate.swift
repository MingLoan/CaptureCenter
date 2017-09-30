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
    
    private func fileOutput(captureOutput: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            self.didStart?()
        }
    }
    
    @objc(captureOutput:didFinishRecordingToOutputFileAtURL:fromConnections:error:) func fileOutput(_ output: AVCaptureFileOutput,
                                                                                                    didFinishRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?){
        DispatchQueue.main.async {
            self.willFinish?()
        }
    }
    
    func fileOutput(captureOutput: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
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
    
//    func fileOutput(_ output: AVCaptureFileOutput,
//                    didPauseRecordingTo fileURL: URL,
//                    from connections: [AVCaptureConnection]){
//
//    }
//
//    func fileOutput(_ output: AVCaptureFileOutput,
//                    didResumeRecordingTo fileURL: URL,
//                    from connections: [AVCaptureConnection]){
//
//    }
}
