//
//  BLEController.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/10/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import Foundation
import SwiftUI

import Bluejay

struct JsonMessageRx: Receivable {
    var data: String
    
    init(bluetoothData: Data) {
        data = String(data: Data(bluetoothData), encoding: .utf8) ?? ""
        log.debug(data)
    }
}


struct FezCommand: Sendable, Encodable {
    // Command keys
    var fx: String?
    var brt: Int?
    
    // Keys in this struct which should be encoded in the JSON message
    enum CodingKeys: String, CodingKey {
        case fx
        case brt
    }
    
    func toJSON() -> String {
        let encoder = JSONEncoder()
        var encoded = Data()
        do {
            encoded = try encoder.encode(self)
            encoded.append(UInt8(ascii: "\n"))
        } catch let error as NSError {
            log.debug("Failed to encode json: \(error.localizedDescription)")
        }
        return String(data: encoded, encoding: .utf8)!
    }
    
    // Convert this struct to a JSON message for bluejay.write()
    func toBluetoothData() -> Data {
        return Bluejay.combine(sendables: [self.toJSON()])
    }
}


//
// Our implementation of the CB central manager
// MARK: BLEController
//
class BLEController: NSObject, ObservableObject {
    
    // Well-known UUIDs for services we care about
    public static let uartServiceUUID = ServiceIdentifier(uuid: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    public static let uartTxCharUUID  = CharacteristicIdentifier(uuid: "6e400002-b5a3-f393-e0a9-e50e24dcca9e", service: uartServiceUUID)
    public static let uartRxCharUUID  = CharacteristicIdentifier(uuid: "6e400003-b5a3-f393-e0a9-e50e24dcca9e", service: uartServiceUUID)
    
    var bluejay = Bluejay()
    var discoveries = [ScanDiscovery]()
    var msgBuffer = Data()

    @Published var fez = FezState()

    private var scanStartTime: CFAbsoluteTime?
    var scanDuration: CFTimeInterval {
        return scanStartTime == nil ? 0 : (CFAbsoluteTimeGetCurrent() - scanStartTime!)
    }
    
    private var refreshTimer: Timer?
    @Published var stillWaiting = false
    
    @Published var connectionError: String!
    var currentPeripheral: PeripheralIdentifier?

    // Published state variables
    @Published var isBluetoothAvailable = false
    @Published var isConnecting = false
    @Published var isConnected = false
    @Published var connectedRSSI = Int(-127)
    
    // Refresh the principals list on a set interval instead of on every discovery update
    @objc func refreshDiscoveries() {
        // Set stillWaiting to trigger UI notification if we've been scanning for more
        // than 3 seconds without discovering a peripheral
        if discoveries.count == 0 && scanDuration > 3.0 {
            stillWaiting = true
        } else {
            stillWaiting = false
        }

        // Manually notify watchers that we updated the peripheral list
        objectWillChange.send()
    }
    
    
    func startScan() {
        if bluejay.isScanning { return }
        
        // Refresh the peripheral view every second while scanning
        stillWaiting = false
        scanStartTime = CFAbsoluteTimeGetCurrent()
        refreshTimer = Timer.scheduledTimer(timeInterval: 1,
                                            target: self,
                                            selector: #selector(refreshDiscoveries),
                                            userInfo: nil,
                                            repeats: true)
        
        bluejay.scan(
            allowDuplicates: true,
            serviceIdentifiers: [BLEController.uartServiceUUID],

            discovery: { [weak self] (discovery, discoveries) -> ScanAction in
                guard let self = self else { return .stop }
                
                // Update the list if a new discovery was added, otherwise wait
                // until the next refresh interval
                if self.discoveries.count != discoveries.count {
                    self.discoveries = discoveries
                    self.objectWillChange.send()
                } else {
                    self.discoveries = discoveries
                }
                
                return .continue
            },
            
            expired: { [weak self] (expired, discoveries) -> ScanAction in
                guard let self = self else { return .stop }
                self.discoveries = discoveries
                return .continue
            },
            
            stopped: { (discoveries, error) in
                self.refreshTimer?.invalidate()
                self.stillWaiting = false
                self.scanStartTime = nil
                self.discoveries.removeAll()
            }
        )
    }
    
    // Simple toggle to attach to start/stop button
    func toggleScan() {
        if bluejay.isScanning {
            bluejay.stopScanning()
        } else {
            startScan()
        }
    }
    
    func startConnect(peripheral: PeripheralIdentifier) {
        isConnecting = true
        currentPeripheral = peripheral
        bluejay.connect(peripheral, timeout: .seconds(15)) { result in
            switch result {
            case .success:
                log.debug("Connection attempt to: \(peripheral.description) is successful")
            case .failure(let error):
                log.debug("Failed to connect with error: \(error.localizedDescription)")
            }
        }
    }
    
    func stopConnect() {
        bluejay.cancelEverything()
    }
    
    func printStatus() {
        log.debug("isBluetoothAvailable \(self.bluejay.isBluetoothAvailable)")
        log.debug("isBluetoothStateUpdateImminent \(self.bluejay.isBluetoothStateUpdateImminent)")
        log.debug("isConnecting \(self.bluejay.isConnecting)")
        log.debug("isConnected \(self.bluejay.isConnected)")
        log.debug("isDisconnecting \(self.bluejay.isDisconnecting)")
        log.debug("shouldAutoReconnect \(self.bluejay.shouldAutoReconnect)")
        log.debug("isScanning \(self.bluejay.isScanning)")
        log.debug("hasStarted \(self.bluejay.hasStarted)")
        log.debug("isBackgroundRestorationEnabled \(self.bluejay.isBackgroundRestorationEnabled)")
    }
    
    func write(_ command: FezCommand) {
        self.bluejay.write(to: BLEController.uartTxCharUUID, value: command) { result in
            switch result {
            case .success:
                log.debug("TX success: \(command.toJSON())")
            case .failure(let error):
                log.debug("TX failed: \(error)")
            }
        }
    }
    
    override init() {
        super.init()
        bluejay.start()
        bluejay.register(connectionObserver: self)
        bluejay.register(rssiObserver: self)
    }
}

// MARK: ConnectionObserver
extension BLEController: ConnectionObserver {
    
    // Called when Bluetooth central manager changes state
    func bluetoothAvailable(_ available: Bool) {
        isBluetoothAvailable = available
        if available {
            startScan()
        }
    }

    // Called whenever a peripheral connects
    func connected(to peripheral: PeripheralIdentifier) {
        log.debug("connected(to: \(peripheral))")

        refreshRSSI()
        isConnecting = false
        isConnected = true
        
        // Check RSSI of the connected peripheral once per second
        refreshTimer = Timer.scheduledTimer(timeInterval: 1,
                                            target: self,
                                            selector: #selector(refreshRSSI),
                                            userInfo: nil,
                                            repeats: true)
        
        bluejay.listen(to: BLEController.uartRxCharUUID, multipleListenOption: .replaceable) {
            [weak self] (result: ReadResult<String>) in
            guard let self = self else { return }
            
            switch result {
            case .success(let msg):
                for char in msg.utf8 {
                    if( char == UInt8(ascii: "\n") ) {
                        do {
                           // make sure this JSON is in the format we expect
                            if let json = try JSONSerialization.jsonObject(with: self.msgBuffer, options: []) as? [String: Any] {
                               // try to read out a string array
                               if let amp = json["amp"] as? NSNumber {
                                   self.fez.maDraw = Float(truncating: amp)
                               }
                               if let fps = json["fps"] as? NSNumber {
                                   self.fez.FPS = Int(truncating: fps)
                               }
                               /*
                               if let brt = json["brt"] as? NSNumber {
                                   self.fez.brightness = Float(truncating: brt)
                               }
                               */
                           }
                       } catch let error as NSError {
                           log.debug("Failed to parse json: \(error.localizedDescription)")
                       }
                        
                        self.msgBuffer = Data()
                    } else {
                        self.msgBuffer.append(char)
                        if self.msgBuffer.count >= 255 {
                            self.msgBuffer = Data()
                        }
                    }
                }
                
            case .failure(let error):
                log.debug("RX failed: \(error)")
            }
        }
    }

    // Called whenever a peripheral disconnects
    func disconnected(from peripheral: PeripheralIdentifier) {
        log.debug("disconnected(from: \(peripheral))")
        isConnecting = bluejay.shouldAutoReconnect
        isConnected = false
        refreshTimer?.invalidate()
        connectedRSSI = -127

        // Forget the current peripheral if we're not reconnecting
        if !isConnecting {
            currentPeripheral = nil
        }
    }

    @objc func refreshRSSI() {
        try? bluejay.readRSSI()
    }
}

// MARK: RSSIObserver
extension BLEController: RSSIObserver {
    func didReadRSSI(from peripheral: PeripheralIdentifier, RSSI: NSNumber, error: Error?) {
        connectedRSSI = RSSI.intValue
    }
}
