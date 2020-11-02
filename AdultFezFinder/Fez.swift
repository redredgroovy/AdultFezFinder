//
//  Fez.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/19/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import SwiftUI

struct Fez: View {
    @EnvironmentObject var fezState: FezState
    @EnvironmentObject var bleController: BLEController
    
    @State var brightness = Float(128.0)
    let debouncer = Debouncer(delay: 0.1)
    
    var body: some View {
        NavigationView {

            VStack {
                PowerMeter()
                    .frame(height: 15)
                HStack {
                    Button(action: { self.bleController.stopConnect() }) {
                        //Text("test")
                        Image(systemName: "power")
                            .font(Font.title.weight(.bold))
                            .foregroundColor(Color.red)
                    }
                    .padding(.trailing)
                    VStack {
                        Text("FPS: \(bleController.fez.FPS)")
                        .font(.system(.body, design: .monospaced))
                        .bold()
                        .minimumScaleFactor(.leastNonzeroMagnitude)
                            .frame(height: 15)

                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("RSSI: \(bleController.connectedRSSI)")
                        .bold()
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(colorBasedOnStrength(bleController.connectedRSSI))
                        .minimumScaleFactor(.leastNonzeroMagnitude)
                            .frame(height: 15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                HStack {
                    Text("Brightness")
                    // value: $bleController.fez.brightness
                    //self.fezState.maDraw = $0

                    Slider(value: Binding<Float>(
                        get: { self.brightness },
                        set: {
                            self.brightness = $0
                            self.sendBrightnessUpdate($0)
                        }), in: 0...255, step: 1)
                }
                
                HStack {
                    Text("Routine")
                    Spacer()
                    NavigationLink(destination: RoutinePicker()) {
                        Text(self.bleController.fez.currentRoutineKey ?? "Unknown")
                        Text(" >")
                    }
                }
                
                Spacer()
            }
        }
        .padding([.horizontal, .top])
        .alert(isPresented: $bleController.isConnecting) {
            Alert(
                title: Text("Connecting to \(self.bleController.currentPeripheral!.name)"),
                message: Text("Press Cancel to abort"),
                dismissButton: .default(Text("Cancel")) { self.bleController.stopConnect() }
            )
        }
    }
    
    func sendBrightnessUpdate(_ brt: Float) {
        debouncer.run(action: {
            self.bleController.write( FezCommand(brt: Int(brt)) )
        })
    }
}

struct RoutinePicker: View {
    @EnvironmentObject var bleController: BLEController

    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        VStack {
            List(bleController.fez.routines) { routine in
                if routine.key == self.bleController.fez.currentRoutineKey {
                    Text("check")
                }
                Button(action: {
                    self.bleController.fez.currentRoutineKey = routine.key
                    self.bleController.write( FezCommand(fx: routine.key) )
                    self.bleController.objectWillChange.send()
                    // Return to main fez view
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text(routine.label)
                }
            }
            
            Spacer()
        }
    }
}

        
struct Fez_Previews: PreviewProvider {
    static let bleController = BLEController()
    static let fezState = FezState()
    
    static var previews: some View {
        Fez()
            .environmentObject(bleController)
            .environmentObject(fezState)
    }
}
