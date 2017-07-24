# CaptureCenter

[![CI Status](http://img.shields.io/travis/mingloan/CaptureCenter.svg?style=flat)](https://travis-ci.org/mingloan/CaptureCenter)
[![Version](https://img.shields.io/cocoapods/v/CaptureCenter.svg?style=flat)](http://cocoapods.org/pods/CaptureCenter)
[![License](https://img.shields.io/cocoapods/l/CaptureCenter.svg?style=flat)](http://cocoapods.org/pods/CaptureCenter)
[![Platform](https://img.shields.io/cocoapods/p/CaptureCenter.svg?style=flat)](http://cocoapods.org/pods/CaptureCenter)

## Introduction
CaptureCenter is not a custom camera cature UI libray. It provides a simple interface layer to bridge functionalities of AVFoundation. CaptureCenter provides interfaces for AVCaptureDevice settings such as focusing, adjusting exposure, applying flash, etc. Moreover, CaptureCenter handles photo capture and video recoprding  pipelines behind the scene. Developers can build their own camera UI with their own UI components or icons and map the UI actions with the interfaces provided from CaptureCenter.

## Example
To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements
Capture Center supports iOS 9.0 or up

## Installation

CaptureCenter is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "CaptureCenter"
```
or via Carthage

In Cartfile
```ruby
github "MingLoan/CaptureCenter"
```
then run
```
carthage update --platform iOS
```

## Usage

### Instantiation

```
let captureCenter = CaptureCenter(captureMode: .photo)
```

Only **photo** capture mode is supported right now, other modes view be supported soon.
```
public enum CaptureMode {
    case photo
    // unsupport now
    case video(size: VideoSize, location: URL, didStart: () -> (), progress: (CGFloat) -> (), willFinish: () -> (), completion: (AVAsset?) -> ())
    // unsupport now
    case stream
}
```

You can simply get the camera preview view from **CaptureCenter** instance and use it as a UIView.

```
captureCenter.previewView.frame = CGRect(...)
view.addSubview(captureCenter.previewView)
```

To start capture, call **startCapturingWithDevicePosition**, you can set device position in advanced.
**cameraControlShouldOn** enables camera control like tap to focus, pinch to zoom, default is **false**
The callback will be called after started capturing.

```
  captureCenter.startCapturingWithDevicePosition(
                .back,
                fromVC: self,
                cameraControlShouldOn: true) { [weak self] finished in
                    guard let strongSelf = self else { return }
                    if finished {
                        // ...
                    }
                }
```

To stop capture,
```
    captureCenter.stopCapturing()
```

### take photo
```
public func captureWithOptions(_ options: ImageOptions, completion: @escaping ((Data?) -> ()))
```

### toggle camera
```
public func changeCameraWithStartBlock(_ startBlock: (() -> ()), finished endBlock: @escaping ((Bool) -> ()))
```

### configure focus
```
public func focusWithMode(_ focusMode: AVCaptureFocusMode, exposureMode: AVCaptureExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool, showUI: @escaping ((Bool) -> ()))
```

### configure exposure
```
public func exposeWithBias(_ exposureBias: CGFloat)
```

### configure zoom
```
public func setZoomScale(_ scale: CGFloat)
```


## Planning
* support video recording
* support streaming
* support RAW capture
* improve documentation

## Author

mingloan, mingloanchan@gmail.com

## License

CaptureCenter is available under the MIT license. See the LICENSE file for more info.
