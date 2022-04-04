//
//  BLEController.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/10/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import UIKit // Required in order to import Bluejay via Swift package manager
import Bluejay

func maphue(_ n:Float, _ start1:Float, _ stop1:Float, _ start2:Float, _ stop2:Float) -> Float {
    return ((n-start1)/(stop1-start1))*(stop2-start2)+start2;
};

struct JsonMessageRx: Receivable {
    var data: String
    
    init(bluetoothData: Data) {
        data = String(data: Data(bluetoothData), encoding: .utf8) ?? ""
        log.debug(data)
    }
}


// JSON model for decoding messages from device
struct JsonModel: Codable {

    let state: State?
    let config: Config?

    struct State: Codable {
        let run: Int32
        
        let fps: Int
        
        let brt: Int
        let max_brt: Int
        
        let v: Float
        let pwr: Float

    }
    
    struct Config: Codable {
        
        struct Routine: Codable {
            let key: String
            let label: String
            let i_brt: Int
            let d_hue: Int
            let d_rainbow: Bool
            let d_text: String
            
        }
        
        let routines: [Routine]
        let routine: String

        let rainbow: Bool
        let hue: Int
        let text: String
        
        let led_v: Float?
        let max_pwr: Float
        let tgt_brt: Int
    }
}


// JSON model for encoding messages to device
struct FezCommand: Sendable, Encodable {
    // Command keys
    var sync: Bool?
    var fx: String?
    var brt: Int?
    var hue: Int?
    var rainbow: Bool?
    var text: String?
    
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
    
    private var syncTimer: Timer?
    @Published var isSynced = false
    
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
        if discoveries.count == 0 && scanDuration > 0.5 {
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
                                            target: self, selector: #selector(refreshDiscoveries),
                                            userInfo: nil,
                                            repeats: true)
        
        bluejay.scan(
            allowDuplicates: true,
            serviceIdentifiers: [BLEController.uartServiceUUID],
            //serviceIdentifiers: [],

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
        bluejay.connect(peripheral, timeout: .seconds(5)) { result in
            switch result {
            case .success:
                log.debug("Connection attempt to: \(peripheral.description) is successful")
            case .failure(let error):
                log.debug("Failed to connect with error: \(error.localizedDescription)")
            }
        }
    }
    
    func stopConnect() {
        syncTimer?.invalidate()
        bluejay.disconnect()
        bluejay.cancelEverything()
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

        isConnecting = false
        isConnected = true
        
        // Flood sync request messages on initial connect
        syncRequest()
        syncTimer = Timer.scheduledTimer(timeInterval: 0.25,
                                         target: self, selector: #selector(syncRequest),
                                         userInfo: nil,
                                         repeats: true)
        
        // Check RSSI of the connected peripheral once per second
        refreshRSSI()
        refreshTimer = Timer.scheduledTimer(timeInterval: 1,
                                            target: self, selector: #selector(refreshRSSI),
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
                            let json = try JSONDecoder().decode(JsonModel.self, from: self.msgBuffer)
                            
                            if( json.config != nil ) {
                                // Reset and build the animation routine list
                                self.fez.routines = [String : FezRoutine]()
                                for routine in json.config!.routines {
                                    let fx = FezRoutine(
                                        key: routine.key,
                                        label: routine.label,
                                        idealBrightness: routine.i_brt,
                                        // Swift expects 0-359 for the hue spectrum but FastLED uses 0-255
                                        defaultHue: Int(maphue(Float(routine.d_hue), 0, 255, 0, 359)),
                                        defaultRainbowToggle: routine.d_rainbow,
                                        defaultText: routine.d_text
                                    )
                                    self.fez.routines[routine.key] = fx
                                }
                                
                                // Use a placeholder Routine definition if we can't find what we want
                                if self.fez.routines[json.config!.routine] == nil {
                                    self.fez.currentRoutine = unknownRoutine
                                } else {
                                    self.fez.currentRoutine = self.fez.routines[json.config!.routine]
                                }
                                
                                self.fez.powerMax = json.config!.max_pwr
                                self.fez.ledVoltage = json.config?.led_v ?? DEFAULT_LED_VOLTAGE
                                self.fez.targetBrightness = Float(json.config!.tgt_brt)

                                // Swift expects 0-359 for the hue spectrum but FastLED uses 0-255
                                self.fez.hue = Int(maphue(Float(json.config!.hue), 0, 255, 0, 359))
                                self.fez.customHueToggle = (self.fez.hue == self.fez.currentRoutine!.defaultHue) ? false : true
                                self.fez.selectedHue = Float(self.fez.hue)
                                
                                self.fez.rainbowToggle = json.config!.rainbow
                                self.fez.text = json.config!.text
                                
                                self.isSynced = true
                                self.syncTimer?.invalidate()
                            }
                            
                            if( json.state != nil && self.isSynced ) {
                                self.fez.uptime = json.state!.run
                                
                                
                                self.fez.FPS = json.state!.fps

                                self.fez.scaledBrightness = json.state!.brt
                                self.fez.maxBrightness = json.state!.max_brt
                             
                                self.fez.batteryVoltage = json.state!.v
                                self.fez.powerDraw = json.state!.pwr
                                self.fez.powerDataSource.push(value: CGFloat(self.fez.powerDrawPct))
                            }
                        
                        } catch let error as NSError {
                            log.debug("Failed to parse json: \(error.localizedDescription)")
                            log.debug("\(self.msgBuffer)")
                        }
                        
                        // Clear buffer and start over
                        self.msgBuffer = Data()
                        
                    } else {
                        self.msgBuffer.append(char)
                        
                        // Buffer overflow, discard and hope for the best
                        if self.msgBuffer.count >= 4096 {
                            log.debug("BLE receive buffer overflow, discarding.")
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
        isSynced = false
        syncTimer?.invalidate()
        refreshTimer?.invalidate()
        connectedRSSI = -127

        // Forget the current peripheral if we're not reconnecting
        if !isConnecting {
            currentPeripheral = nil
            fez.reset()
        }
    }

    @objc func refreshRSSI() {
        try? bluejay.readRSSI()
    }
    
    @objc func syncRequest() {
        self.write( FezCommand(sync: true) )
    }
}


// MARK: RSSIObserver
extension BLEController: RSSIObserver {
    func didReadRSSI(from peripheral: PeripheralIdentifier, RSSI: NSNumber, error: Error?) {
        connectedRSSI = RSSI.intValue
    }
}
