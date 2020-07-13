//
//  Timers.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/12/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import Foundation

class Countdown {
    let timer: Timer
    
    init(seconds: TimeInterval, closure: @escaping () -> ()) {
        timer = Timer.scheduledTimer(withTimeInterval: seconds,
                repeats: false, block: { _ in
            closure();
        })
    }
    
    deinit {
        timer.invalidate()
    }
}
