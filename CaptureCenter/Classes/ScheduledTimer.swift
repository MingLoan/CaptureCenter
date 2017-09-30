//
//  ScheduledTimer.swift
//  chaatz
//
//  Created by Mingloan Chan on 6/3/2016.
//  Copyright © 2016 Chaatz. All rights reserved.
//

import Foundation

class ScheduledTimer {
    
    fileprivate var privateTimer: Timer?
    fileprivate var gcdTimer: DispatchSourceTimer?
    
    fileprivate var executionBlock: ((Timer?) -> ()) = { _ in }

    class func schedule(_ intervalFromNow: TimeInterval, block: @escaping (Timer?) -> (), timerObject: ((ScheduledTimer) -> ())? = nil) {
        
        let sTimer = ScheduledTimer()
        
        if #available(iOS 10.0, *) { }
        else {
            sTimer.executionBlock = block
        }
        
        if !Thread.isMainThread {
            // Use GCD Timer
            let timer =
                DispatchSource.makeTimerSource(
                    flags: DispatchSource.TimerFlags(rawValue: UInt(0)),
                    queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))
            
            timer.schedule(deadline: DispatchTime.now() + intervalFromNow)
            timer.setEventHandler {
                block(nil)
                if let timer = sTimer.gcdTimer {
                    timer.cancel()
                }
            }
            sTimer.gcdTimer = timer
            timerObject?(sTimer)
            timer.resume()
        }
        else {
         
            // Use NSTimer
            if #available(iOS 10.0, *) {
                let timer = Timer.scheduledTimer(withTimeInterval: intervalFromNow, repeats: false) { t in
                    block(t)
                }
                sTimer.privateTimer = timer
                timerObject?(sTimer)
                RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
            }
            else {
                let timer =
                    Timer.scheduledTimer(
                        timeInterval: intervalFromNow,
                        target: sTimer,
                        selector: #selector(execute(_:)),
                        userInfo: nil,
                        repeats: false)
                sTimer.privateTimer = timer
                timerObject?(sTimer)
                RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
            }
        }

    }
    
    class func schedule(every interval: TimeInterval, block: @escaping (Timer?) -> (), timerObject: ((ScheduledTimer) -> ())? = nil) {
        
        let sTimer = ScheduledTimer()
        sTimer.executionBlock = block
        
        if !Thread.isMainThread {
            // Use GCD Timer
            let timer =
                DispatchSource.makeTimerSource(
                    flags: DispatchSource.TimerFlags(rawValue: UInt(0)),
                    queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))
            
            let deadline = DispatchTime.now() + interval
            timer.schedule(deadline: deadline, repeating: interval)
            timer.setEventHandler {
                block(nil)
            }
            sTimer.gcdTimer = timer
            timerObject?(sTimer)
            timer.resume()
        }
        else {
            // Use NSTimer
            
            if #available(iOS 10.0, *) {
                let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
                    block(t)
                }
                sTimer.privateTimer = timer
                timerObject?(sTimer)
                RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
            }
            else {
                let timer =
                    Timer.scheduledTimer(
                        timeInterval: interval,
                        target: sTimer,
                        selector: #selector(execute(_:)),
                        userInfo: nil,
                        repeats: true)
                sTimer.privateTimer = timer
                timerObject?(sTimer)
                
                RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
            }
        }
    }
    
    @objc fileprivate func execute(_ timer: Timer) {
        executionBlock(timer)
    }
    
    func invalidate() {
        if !Thread.isMainThread {
            if let timer = gcdTimer {
                timer.cancel()
            }
        }
        else {
            privateTimer?.invalidate()
        }
    }
    
    class func add(timer t: ScheduledTimer, to: RunLoop, forMode mode: RunLoopMode) {
        if let timer = t.privateTimer {
            to.add(timer, forMode: mode)
        }
    }
    
}

extension Int {
    
    var degreesToRadians : CGFloat {
        return CGFloat(self) * CGFloat(Double.pi) / 180.0
    }
    
    var second:  TimeInterval { return TimeInterval(self) }
    var seconds: TimeInterval { return TimeInterval(self) }
    var minute:  TimeInterval { return TimeInterval(self * 60) }
    var minutes: TimeInterval { return TimeInterval(self * 60) }
    var hour:    TimeInterval { return TimeInterval(self * 3600) }
    var hours:   TimeInterval { return TimeInterval(self * 3600) }
}

extension Double {
    var second:  TimeInterval { return self }
    var seconds: TimeInterval { return self }
    var minute:  TimeInterval { return self * 60 }
    var minutes: TimeInterval { return self * 60 }
    var hour:    TimeInterval { return self * 3600 }
    var hours:   TimeInterval { return self * 3600 }
}
