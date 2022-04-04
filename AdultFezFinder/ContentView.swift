//
//  ContentView.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/19/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import SwiftUI

// Hack to allow negation of a Binding<Bool>
extension Binding where Value == Bool {
    var not: Binding<Value> {
        Binding<Value>(
            get: { !self.wrappedValue },
            set: { self.wrappedValue = !$0 }
        )
    }
}


// MARK: BluetoothDisabled
// Modal to display warning when Bluetooth is disabled
struct BluetoothDisabled<Content>: View where Content: View {
    @Binding var isShowing: Bool  // should this modal be visible?
    var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                // the content to display ordinarily
                content()
                    .disabled(isShowing)
                    .blur(radius: isShowing ? 4 : 0)
                
                // all contents inside here will only be shown when isShowing is true
                if isShowing {
                    // this Rectangle is a semi-transparent black overlay
                    Rectangle()
                        .fill(Color.black).opacity(isShowing ? 0.1 : 0)
                        .edgesIgnoringSafeArea(.all)

                    // Modal content
                    VStack {
                        Text("Please enable Bluetooth")
                        Text("for Fez communication")
                    }
                    .padding()
                    .background(Color.white)
                    .foregroundColor(Color.primary)
                    .cornerRadius(16)
                    .shadow(radius: 16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 1))
                }
            }
        }
    }
}

// MARK: NoPeripheralsFound
// Model to provide feedback when no peripherals are detected
struct NoPeripheralsFound<Content>: View where Content: View {
    @Binding var isShowing: Bool  // should this modal be visible?
    var content: () -> Content
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                // the content to display ordinarily
                content()
                    .disabled(isShowing)
                    .blur(radius: isShowing ? 4 : 0)
                
                // all contents inside here will only be shown when isShowing is true
                if isShowing {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(2.0, anchor: .center)
                            .padding()
                        Text("Scanning for Bluetooth devices...")
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 1))
                }
            }
        }
    }
}

// MARK: PeripheralList
// List of discovered devices and their most recent RSSI
struct PeripheralList: View {
    @EnvironmentObject var bleController: BLEController
    
    var body: some View {
        // Provide informative model after a few seconds
        NoPeripheralsFound(isShowing: $bleController.stillWaiting) {
            List {
                ForEach(bleController.discoveries, id: \.peripheralIdentifier.uuid) { discovery in
                    HStack {
                        Text(discovery.peripheralIdentifier.name).lineLimit(1)
                        Spacer()
                        Text("NN").hidden().overlay(SignalStrengthBars(rssi: discovery.rssi))
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
            }
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
                    .padding()
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var bleController: BLEController

    var body: some View {
        VStack {
            Text("Adult Fez Finder")
                .font(.headline)
            if bleController.isConnecting || bleController.isConnected {
                Fez()
            } else {
                BluetoothDisabled(isShowing: $bleController.isBluetoothAvailable.not) {
                    VStack {
                        PeripheralList()
                        ScanToggleButton()
                    }
                    .onAppear {
                        self.bleController.startScan()
                    }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static let bleController = BLEController()
    static var previews: some View {
        ContentView()
            .environmentObject(bleController)
    }
}
