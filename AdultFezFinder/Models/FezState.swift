//
//  FezState.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/10/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import Foundation

final class FezState: NSObject, ObservableObject {
 
    // Fez power management
    @Published var maDraw = Float(0.0)
    @Published var maMax = Float(30.0)
    var maCapacity: Float {
        return (maDraw / maMax)
    }
    
    // Fez animation/routine management
    @Published var currentAnimation: String?

    // Connected BLEPeripheral
    @Published var peripheral: BLEPeripheral?
}
