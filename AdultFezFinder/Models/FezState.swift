//
//  FezState.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/10/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import Foundation

import DSFSparkline

let DEFAULT_LED_VOLTAGE     = Float(5.0)
let DEFAULT_BATTERY_VOLTAGE = Float(12.0)
let DEFAULT_POWER_MAX       = Float(1.0)
let DEFAULT_BRIGHTNESS      = Int(32)

struct FezRoutine : Identifiable, Hashable {
    let id = UUID()
    let key: String
    let label: String
    
    let idealBrightness: Int
    let defaultHue: Int
    let defaultRainbowToggle: Bool
    let defaultText: String
}
let unknownRoutine = FezRoutine(
    key: "unknown",
    label: "Unknown",
    
    idealBrightness: 32,
    defaultHue: -1,
    defaultRainbowToggle: false,
    defaultText: ""
)

final class FezState: NSObject, ObservableObject {
    @Published var routines = [String : FezRoutine]()
    
    // Routine configuration data
    @Published var currentRoutine: FezRoutine?
    @Published var hue = Int(-1)
    @Published var selectedHue = Float(0);
    @Published var customHueToggle = false
    @Published var rainbowToggle = false
    @Published var text = ""
    
    // Fez status data
    @Published var ledVoltage = Float(DEFAULT_LED_VOLTAGE)
    @Published var batteryVoltage = Float(DEFAULT_BATTERY_VOLTAGE)
    @Published var uptime = Int32(0)
    
    @Published var powerDraw = Float(0.0)
    @Published var powerMax = Float(DEFAULT_POWER_MAX)
    var powerDrawPct: Float {
        return (powerDraw / powerMax)
    }
    var currentDraw: Float {
        return powerDraw / ledVoltage
    }
    var currentMax: Float {
        return powerMax / ledVoltage
    }
    
    // Store approximately 60 seconds worth of historical power samples
    @Published var powerDataSource = DSFSparkline.DataSource(windowSize: 240, range: 0.0 ... 1.0)

    @Published var targetBrightness = Float(DEFAULT_BRIGHTNESS) // directly manipulated by UI Slider
    @Published var scaledBrightness = Int(DEFAULT_BRIGHTNESS)
    @Published var maxBrightness    = Int(DEFAULT_BRIGHTNESS)

    @Published var FPS = Int(0)
    
    @Published var initialized = false
    
    // Clear state when we disconnect/change peripherals
    func reset() {
        self.currentRoutine = nil
        
        self.hue = -1
        self.selectedHue = 0
        self.customHueToggle = false
        self.rainbowToggle = false
        self.text = ""
        
        self.ledVoltage = DEFAULT_LED_VOLTAGE
        self.batteryVoltage = DEFAULT_BATTERY_VOLTAGE
        self.uptime = 0
        
        self.powerDraw = 0.0
        self.powerMax = DEFAULT_POWER_MAX
        self.powerDataSource.reset()
        
        self.scaledBrightness = DEFAULT_BRIGHTNESS
        self.maxBrightness = DEFAULT_BRIGHTNESS
    
        self.FPS = 0
        self.initialized = false
    }
}
