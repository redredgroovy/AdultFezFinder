//
//  BLEScanner.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/11/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import SwiftUI

// Thresholds based on anecdotal experience
func colorBasedOnStrength(_ rssi: Int) -> Color {
    if rssi >= -65 {
        return Color.green
    } else if rssi >= -75 {
        return Color.orange
    } else {
        return Color.red
    }
}

// Pop-up notification requesting Bluetooth be enabled
struct BluetoothDisabledAlert: View {
    var body: some View {
        VStack {
            Text("Please enable Bluetooth")
            Text("for Fez communication")
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 1))
    }
}

// Pop-up notification when no periperals are detected
struct NoDevicesFoundAlert: View {
    var body: some View {
        VStack {
            Text("Scanning for Bluetooth devices...")
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 1))
    }
}

// List of discovered devices and their most recent RSSI
struct PeripheralList: View {
    @EnvironmentObject var bleController: BLEController
    @EnvironmentObject var fezState: FezState

    var body: some View {
        VStack {
            HStack {
                Text("Device")
                Spacer()
                Text("RSSI")
            }
            .padding(.horizontal)
            
            Rectangle()
                .frame(height: 2)
                .shadow(radius: 3)
            List(bleController.discoveries, id: \.peripheralIdentifier.uuid) { discovery in
                HStack {
                    Text("NN").hidden().overlay(SignalStrengthBars(rssi: discovery.rssi))
                    Text(discovery.peripheralIdentifier.name).lineLimit(1)
                    Spacer()
                    Button(action: { self.bleController.startConnect(peripheral: discovery.peripheralIdentifier) }) {
                        Text("Connect")
                            .foregroundColor(.blue)
                            .font(.caption)
                            .padding(7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                    }
                }
            }
            
            Rectangle()
                .frame(height: 2)
                .shadow(radius: 3)
        }
    }
}

// Button to enable/disable BLE scanning
struct ScanToggleButton: View {
    @EnvironmentObject var bleController: BLEController

    let minHeight = CGFloat(40.0)
    
    var body: some View {
        HStack {
            Button(action: { self.bleController.toggleScan() }) {
                Text((bleController.bluejay.isScanning ? "Stop" : "Start") + " Scanning")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: minHeight)
                    .frame(height: minHeight)
                    .background(Color.blue)
                    .cornerRadius(40)
                    .padding([.top, .bottom, .leading])
            }
            
            // Switch between antenna icon and activity scanner based on state
            if bleController.bluejay.isScanning {
                ActivityIndicator(show: .constant(true))
                    .frame(minHeight: minHeight)
                    .frame(width: 60)
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(Font.title.weight(.semibold))
                    .foregroundColor(Color.blue)
                    .frame(minHeight: minHeight)
                    .frame(width: 60)
            }
        }
    }
}

//
// Assemble all UI components into a single view with ZStacks for notification popups
// MARK: BLEScanner
//
struct BLEScanner: View {
    @EnvironmentObject var bleController: BLEController
    
    var body: some View {
        
        // ZStack for the entire View
        ZStack {
            VStack {
                Text("Adult Fez Finder")
                    .font(.headline)

                Divider()
                Section {
                

                // ZStack for just the peripheral list
                ZStack {
                    PeripheralList()
                        // Blur peripheral list and prevent it from receiving
                        // input when scanning is disabled
                        .blur(radius: bleController.bluejay.isScanning ? 0 : 2)
                        .allowsHitTesting(bleController.bluejay.isScanning)
                    
                    // Create gray overlay when scanning is disabled
                    if !bleController.bluejay.isScanning {
                        Rectangle()
                            .fill(Color.black)
                            .opacity(0.1)
                            .blur(radius: 20)
                            .edgesIgnoringSafeArea([.bottom])

                    // Provide feedback when no devices are detected
                    } else if bleController.stillWaiting {
                        NoDevicesFoundAlert()
                    }
 
                }
                
                ScanToggleButton()
            }
            }
            
            // Create blue overlay when peripheral controls are disabled
            if !bleController.isBluetoothAvailable {
                Rectangle()
                    .fill(Color.blue)
                    .opacity(0.1)
                    .blur(radius: 20)
                    .edgesIgnoringSafeArea([.bottom])
                BluetoothDisabledAlert()
            }
        }
        .onAppear {
            self.bleController.startScan()
        }
    }
}

struct BLEScanner_Previews: PreviewProvider {
    static let bleController = BLEController()
    static var previews: some View {
        BLEScanner().environmentObject(bleController)
    }
}
