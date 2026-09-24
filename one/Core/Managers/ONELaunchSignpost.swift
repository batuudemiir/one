//
//  ONELaunchSignpost.swift
//  one
//
//  Minimal os_signpost + wall-clock timing for the launch path.
//  Use with Instruments → Points of Interest to see splash/CloudKit/pattern
//  segments overlaid on the Time Profiler.
//
//  DEBUG builds also print elapsed milliseconds so you can eyeball a run
//  without spinning up Instruments.
//

import Foundation
import os.signpost

enum ONELaunchSignpost {
    private static let log = OSLog(subsystem: "com.batu.ones.launch", category: .pointsOfInterest)
    private static var startTimes: [String: CFAbsoluteTime] = [:]
    private static let queue = DispatchQueue(label: "one.launch.signpost")

    static func begin(_ name: StaticString) {
        let key = "\(name)"
        queue.sync {
            startTimes[key] = CFAbsoluteTimeGetCurrent()
        }
        os_signpost(.begin, log: log, name: name)
    }

    static func end(_ name: StaticString) {
        os_signpost(.end, log: log, name: name)
        #if DEBUG
        let key = "\(name)"
        var elapsed: CFTimeInterval = 0
        queue.sync {
            if let start = startTimes.removeValue(forKey: key) {
                elapsed = CFAbsoluteTimeGetCurrent() - start
            }
        }
        if elapsed > 0 {
            let ms = Int((elapsed * 1000).rounded())
            print("[launch] \(key): \(ms)ms")
        }
        #endif
    }

    static func event(_ name: StaticString) {
        os_signpost(.event, log: log, name: name)
    }
}
