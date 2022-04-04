//
//  Timers.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/12/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import Foundation

//
// A wrapper to ensure that action is executed no more than once per TimeInterval
//
// This helps us "throttle" or otherwise reduce the overhead of calling a function
// which is triggered by rapid UI events, such as a slider being modified
//
// Example:
// let throttler = Throttle(delay: 0.1)
// throttler.run(action: {...})
//
class Throttler {
    private let delay: TimeInterval
    
    private var workItem: DispatchWorkItem?
    private var lastExecution: DispatchTime = .now()
    
    init(delay: TimeInterval) {
        self.delay = delay
    }

    // Trigger the action after some delay, reset the action if it has not yet triggered
    public func run(action: @escaping () -> Void) {
        workItem?.cancel()
        //workItem = DispatchWorkItem(block: action)
        workItem = DispatchWorkItem { [weak self] in
            if let selfStrong = self {
                selfStrong.lastExecution = .now()
            }
            action()
        }
        DispatchQueue.main.asyncAfter(deadline: (self.lastExecution + delay), execute: workItem!)
    }
}
