//
//  FezState.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/10/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import Foundation

struct FezRoutine : Identifiable, Hashable {
    let id = UUID()
    let key: String
    let label: String
}

final class FezState: NSObject, ObservableObject {
 
    let routines = [
        FezRoutine(key: "null", label: "Null"),
        FezRoutine(key: "fauxtv", label: "FauxTV"),
        FezRoutine(key: "pacifica", label: "Pacifica"),
        FezRoutine(key: "twinklefox", label: "TwinkleFOX")
    ]
    @Published var currentRoutineKey: String?

    // Fez status data
    @Published var maDraw = Float(0.0)
    @Published var maMax = Float(1.0)
    var maCapacity: Float {
        return (maDraw / maMax)
    }
    
    @Published var brt = Float(128.0)
    @Published var brightness = Float(128.0)

    @Published var FPS = Int(0)
    
    private var fakeTimer: Timer?
    @objc func fakeFPS() {
        FPS = Int.random(in: 15..<100)
    }
    
    override init() {
        super.init()
        /*
        fakeTimer = Timer.scheduledTimer(timeInterval: 1,
                                         target: self,
                                         selector: #selector(fakeFPS),
                                         userInfo: nil,
                                         repeats: true)
        */
    }
}
