//
//  BLEController.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/10/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import CoreBluetooth
import Foundation

//
// Class for wrapping a CBPeripheral object with additional metadata
// MARK: BLEPeripheral
//
class BLEPeripheral: NSObject, Identifiable {
    
    // Well-known UUIDs for services we care about
    public static let uartServiceUUID = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    public static let uartTxCharUUID  = CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    public static let uartRxCharUUID  = CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    
    var peripheral: CBPeripheral
    var rssi: Int

    // Track when an announcement was last seen from this peripheral
    let discoveryTimeout = Double(10.0)
    var lastSeen: CFAbsoluteTime
    var discoveryTimedOut: Bool {
        return (CFAbsoluteTimeGetCurrent() - lastSeen > discoveryTimeout)
    }
    
    var id: UUID {
        return peripheral.identifier
    }
    
    var name: String {
        return peripheral.name ?? peripheral.identifier.uuidString
    }
    
    var state: CBPeripheralState {
        return peripheral.state
    }
    
    init(peripheral: CBPeripheral, rssi: Int?) {
        self.peripheral = peripheral
        self.rssi = rssi ?? -127
        self.lastSeen = CFAbsoluteTimeGetCurrent()
        
        super.init()
        self.peripheral.delegate = self
    }
}

extension BLEPeripheral: CBPeripheralDelegate {
}

//
// Our implementation of the CB central manager
// MARK: BLEController
//
class BLEController: NSObject, ObservableObject {
    
    var myCentral: CBCentralManager!
    var peripherals = [BLEPeripheral]()
    
    private var discoveryTimer: Timer?
    @Published var stillWaiting = false
    
    private var scanStartTime: CFAbsoluteTime?
    var scanDuration: CFTimeInterval {
        return scanStartTime == nil ? 0 : (CFAbsoluteTimeGetCurrent() - scanStartTime!)
    }
    
    //@Published var isConnecting = false
    
    @Published var state = State.initializing
    enum State {
        case initializing
        case disabled
        case disconnected
        case restoringConnectingPeripheral(BLEPeripheral)
        case restoringConnectedPeripheral(BLEPeripheral)
        case scanning
        case connecting(BLEPeripheral, Countdown)
        case connected(BLEPeripheral)
        
        var peripheral: BLEPeripheral? {
            switch self {
                case .initializing: return nil
                case .disabled: return nil
                case .disconnected: return nil
                case .restoringConnectingPeripheral(let p): return p
                case .restoringConnectedPeripheral(let p): return p
                case .scanning: return nil
                case .connecting(let p, _): return p
                case .connected(let p): return p
            }
        }
        
        // Allow us to test for equality without associated parameters
        enum Case {
            case initializing
            case disabled
            case disconnected
            case restoringConnectingPeripheral
            case restoringConnectedPeripheral
            case scanning
            case connecting
            case connected
        }
        
        var `case`: Case {
            switch self {
            case .initializing: return .initializing
            case .disabled: return .disabled
            case .disconnected: return .disconnected
            case .restoringConnectingPeripheral: return .restoringConnectingPeripheral
            case .restoringConnectedPeripheral: return .restoringConnectedPeripheral
            case .scanning: return .scanning
            case .connecting: return .connecting
            case .connected: return .connected
            }
        }
    }
    
    // Refresh the principals list on a set interval instead of on every discovery update
    @objc func refreshPeripherals() {
        // Set stillWaiting to trigger UI notification if we've been scanning for more
        // than 2 seconds without discovering a peripheral
        if peripherals.count == 0 && scanDuration > 2.0 {
            stillWaiting = true
        }
        
        // Remove any peripherals which haven't been seen lately
        peripherals = peripherals.filter { !$0.discoveryTimedOut }
        
        // Manually notify watchers that we updated the peripheral list
        objectWillChange.send()
    }
    
   
    
    func startScan() {
        state = .scanning
        // let services = [BLEPeripheral.uartServiceUUID]
        myCentral.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])

        // Refresh the peripheral list every second while scanning
        discoveryTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(refreshPeripherals), userInfo: nil, repeats: true)
        scanStartTime = CFAbsoluteTimeGetCurrent()
    }
    
    func stopScan() {
        state = .disconnected
        myCentral.stopScan()
        
        discoveryTimer?.invalidate()
        peripherals.removeAll()
        scanStartTime = nil
        stillWaiting = false
    }
    
    func toggleScan() {
        state.case == .scanning ? stopScan() : startScan()
    }
    
    func startConnect(peripheral: BLEPeripheral) {
        stopScan()
        myCentral.connect(peripheral.peripheral, options: nil)
        
        // Force connection attempt to timeout in 10 seconds
        state = .connecting(peripheral, Countdown(seconds: 10, closure: {
            self.myCentral.cancelPeripheralConnection(peripheral.peripheral)
            self.stopConnect()
        }))
    }
    
    func stopConnect() {
        if state.peripheral != nil {
            myCentral.cancelPeripheralConnection(state.peripheral!.peripheral)
        }
        startScan()
    }
    
    override init() {
        super.init()
        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
    }
    
}

extension BLEController: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            self.state = .disconnected
        } else {
            self.state = .disabled
        }
    }
    
    // Handler for discovering a new peripheral while scanning
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // We've discovered at least one peripheral so we're no longer waiting
        if stillWaiting {
            stillWaiting = false
        }
        
        if let existingPeripheral = peripherals.first(where: {$0.id == peripheral.identifier}) {
            // Update RSSI and lastSeen for peripherals we've already discovered
            existingPeripheral.peripheral = peripheral
            existingPeripheral.rssi = RSSI.intValue
            existingPeripheral.lastSeen = CFAbsoluteTimeGetCurrent()
        } else {
            // Add a new peripheral if we haven't seen it before
            let newPeripheral = BLEPeripheral(peripheral: peripheral, rssi: RSSI.intValue)
            peripherals.append(newPeripheral)
            
            // Manually notify watchers that we updated the peripheral list
            objectWillChange.send()
        }
        
    }
    
    // Handler for successfully connecting to a peripheral with connect()
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if state.case == .connecting && state.case.peripheral.id == peripheral.id {
            state = .connected
        } else {
            print("Received unexpected connect for peripheral \(String(describing: peripheral.name))")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if [.connecting, .connected].contains(state.case) && state.case.peripheral.id == peripheral.id {
            state = .disconnected
        } else {
            print("Received unexpected disconnect for peripheral \(String(describing: peripheral.name))")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if [.connecting, .connected].contains(state.case) && state.case.peripheral.id == peripheral.id {
            state = .disconnected
        } else {
            print("Received unexpected disconnect for peripheral \(String(describing: peripheral.name))")
        }
    }
}
