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
// This helps us "debounce" or otherwise reduce the overhead of calling a function
// which is triggered by rapid UI events, such as a slider being modified
//
// Example:
// let debouncer = Debouncer(delay: 0.1)
// debouncer.run(action: {...})
//
class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    // Trigger the action after some delay, reset the action if it has not yet triggered
    public func run(action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}

//
// Defers calling the provided action until TimeInterval has passed
//
// Example:
// let countdown = Countdown(seconds: 5, action: {...})
///
class Countdown {
    private let timer: Timer
    
    init(seconds: TimeInterval, action: @escaping () -> ()) {
        timer = Timer.scheduledTimer(withTimeInterval: seconds,
                repeats: false, block: { _ in
            action();
        })
    }
    
    deinit {
        timer.invalidate()
    }
}
