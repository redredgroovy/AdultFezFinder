//
//  Fez.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/19/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import SwiftUI

import SwiftUIX
import KeyboardObserving

let cardSpacing: CGFloat = 15.0
let lightGray: Color = Color(red: 185/255, green: 185/255, blue: 190/255)

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

// Thresholds based on generic 11.1V 3S LiPo battery curve
func colorBasedOnVoltage(_ voltage: Float) -> Color {
    if voltage >= 11.35 {
        return Color.green
    } else if voltage >= 11.1 {
        return Color.orange
    } else {
        return Color.red
    }
}

func millisToElapsed(_ millis: Int32) -> String {
    let hours = millis / 1000 / 3600
    let mins = millis / 1000 / 60 % 60
    let secs = millis / 1000 % 60
    return String(format: "%02d:%02d:%02d", hours, mins, secs)
}

// Standardized section divider for Fez status screen
struct FezDivider: View {
    var label: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(lightGray)
            VStack {
                Rectangle()
                    .fill(lightGray)
                    .frame(height: 1)
            }
        }
    }
}

// Standardized drop-shadow card border
struct SectionCard: ViewModifier {
    let padding: CGFloat
    
    init(padding: CGFloat = 8.0) {
        self.padding = padding
    }
    
    func body(content: Content) -> some View {
        return content
            .padding(padding)
            .background(Color(red: 245/255, green: 245/255, blue: 245/255))
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 6, y: 6)
            .shadow(color: Color.white.opacity(0.7), radius: 6, x: -3, y: -3)
    }
}

// Add a button to clear text in TextField
struct TextFieldClearButton: ViewModifier {
    @Binding var text: String
    
    func body(content: Content) -> some View {
        HStack {
            content
            
            if !text.isEmpty {
                Button(
                    action: { self.text = "" },
                    label: {
                        Image(systemName: "delete.left")
                            .foregroundColor(Color(UIColor.opaqueSeparator))
                    }
                )
            }
        }
    }
}

// Primary view for Fez status
struct Fez: View {
    @EnvironmentObject var bleController: BLEController
        
    // Wrapper for max brightness indictator tickmark
    var animatableData: Int {
        get { self.bleController.fez.maxBrightness }
        set { self.bleController.fez.maxBrightness = newValue }
    }
    
    // Throttle the speed by which we send brightness updates
    let brtThrottler = Throttler(delay: 0.2)
    func sendBrtUpdate(_ brt: Float) {
        brtThrottler.run(action: {
            self.bleController.write( FezCommand(brt: Int(brt)) )
        })
    }

    // Throttle the speed by which we send hue updates
    let hueThrottler = Throttler(delay: 0.2)
    func sendHueUpdate(_ hue: Float) {
        hueThrottler.run(action: {
            // Swift uses 0-359 for the hue spectrum but FastLED expects 0-255
            let remappedHue: Int = hue == -1 ? -1 : Int(maphue(hue, 0, 359, 0, 255))
            self.bleController.write( FezCommand(hue: remappedHue))
        })
    }
    
    @State var customText: String = ""
    
    var body: some View {
        
        // Bool binding to trigger isSyncing alert pop-up
        let isSyncing = Binding<Bool>(
            get: { return (bleController.isConnecting || bleController.isConnected) && !bleController.isSynced},
            set: { s in () }
        )
        
        // Binding for the brt slider
        let targetBrtBinding = Binding<Float>(
            get: {
                self.bleController.fez.targetBrightness
            },
            set: {
                self.bleController.fez.targetBrightness = $0
                self.sendBrtUpdate($0)
            }
        )
        
        // Binding for the hue slider
        // Send a hue update if the slider is updated and custom hue is enabled
        let selectedHueBinding = Binding<Float>(
            get: {
                bleController.fez.selectedHue
            },
            set: {
                bleController.fez.selectedHue = $0
                if(bleController.fez.customHueToggle) {
                    self.sendHueUpdate($0)
                }
            }
        )
        
        // Binding for the custom hue toggle
        // Send an update whenever the toggle state changes
        let customHueToggleBinding = Binding<Bool>(
            get: {
                bleController.fez.customHueToggle
            },
            set: {
                bleController.fez.customHueToggle = $0
                if(bleController.fez.customHueToggle) {
                    self.sendHueUpdate(bleController.fez.selectedHue)
                } else {
                    self.sendHueUpdate(-1)
                }
            }
        )
        
        // Binding for the rainbow toggle
        // Send an update whenever the toggle state changes
        let rainbowToggleBinding = Binding<Bool>(
            get: {
                bleController.fez.rainbowToggle
            },
            set: {
                bleController.fez.rainbowToggle = $0
                self.bleController.write( FezCommand(rainbow: $0))
            }
        )
        
        VStack(spacing: cardSpacing) {
            // MARK: Device
            FezDivider(label: "Device")
            
            HStack(spacing: cardSpacing) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Device: \(bleController.currentPeripheral?.name ?? "")")
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .scaledToFill()
                            .minimumScaleFactor(.leastNonzeroMagnitude)
                        Text("Uptime: \(millisToElapsed(bleController.fez.uptime))")
                            .lineLimit(1)
                            .scaledToFill()
                            .monospacedDigit()
                            .minimumScaleFactor(.leastNonzeroMagnitude)
                    }
                    Spacer()
                }
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .modifier(SectionCard())

                VStack(spacing: 5) {
                    SignalStrengthBars(rssi: bleController.connectedRSSI)
                        .padding(.leading, 7)
                        .padding(.trailing, 7)
                        .frame(width: 60, height: 40)
                    SignalStrengthLabel(rssi: bleController.connectedRSSI)
                        .frame(width: 60, height: 15)

                }
                .frame(height: 60)
                .modifier(SectionCard())
           
                Button(action: { self.bleController.stopConnect() }) {
                    Image(systemName: "power")
                        .symbolVariant(.circle)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.black)
                        .font(.system(size: 60))
                        .font(Font.title.weight(.black))
                }
                .frame(width: 60, height: 60)
                .modifier(SectionCard())
            }

            // MARK: Power
            FezDivider(label: "Power")
            
            // Scrolling power sparkline with real-time Amp/Watt indicators
            HStack(spacing: cardSpacing) {
                VStack(spacing: 5) {
                    Text("\(bleController.fez.batteryVoltage, specifier: "%.1f")")
                        .bold()
                        .monospacedDigit()
                        .foregroundColor(colorBasedOnVoltage(bleController.fez.batteryVoltage))
                        .frame(width: 80, height: 40)
                        .lineLimit(1)
                        .font(.system(size: 300))
                        .minimumScaleFactor(.leastNonzeroMagnitude)
                    Text("VBAT")
                        .foregroundColor(colorBasedOnVoltage(bleController.fez.batteryVoltage))
                        .frame(height: 15)
                        .lineLimit(1)
                        .font(.system(size: 300))
                        .minimumScaleFactor(.leastNonzeroMagnitude)
                }
                .frame(height: 60)
                .modifier(SectionCard())
                
                HStack(spacing: 0) {
                    PowerMeterSpark(source: self.bleController.fez.powerDataSource)
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                        .overlay(Rectangle().frame(width: 1, height: nil, alignment: .trailing).foregroundColor(lightGray), alignment: .trailing)
                    VPowerMeterBar(capacity: self.bleController.fez.powerDrawPct)
                        .frame(width: 20 , height: 76)
                }
                .frame(height: 76)
                .frame(maxWidth: .infinity)
                .modifier(SectionCard(padding: 0))
                
                VStack(alignment: .leading) {
                    Text("\(bleController.fez.currentDraw / 1000, specifier: "%4.1f") A")
                        .bold()
                        .monospacedDigit()
                    Text("\(bleController.fez.powerDraw / 1000, specifier: "%4.1f") W")
                        .bold()
                        .monospacedDigit()
                }
                .frame(height: 60)
                .modifier(SectionCard())
            }
            
            
            // Brightness control slider
            HStack {
                Image(systemName: "light.min")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.blue)
                    .font(.system(size: 20))
                    .minimumScaleFactor(.leastNonzeroMagnitude)
                    .font(Font.title.weight(.black))
                GeometryReader { geometry in
                    ZStack {
                        // Live indicator for current theoritical max brightness
                        VStack(spacing: 0) {
                            Image(systemName: "arrowtriangle.down.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 10))
                            Image(systemName: "arrowtriangle.up.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 10))
                        }
                        .position(x: CGFloat(Float(self.bleController.fez.maxBrightness) / 255.0) * geometry.size.width, y: geometry.size.height / 2.0)
                        .animation(.easeInOut(duration: 0.25), value: self.bleController.fez.maxBrightness)
                        Slider(value: targetBrtBinding, in: 1...255, step: 1)
                    }
                }
                Image(systemName: "light.max")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.blue)
                    .font(.system(size: 20))
                    .minimumScaleFactor(.leastNonzeroMagnitude)
                    .font(Font.title.weight(.black))
            }
            .frame(height: 30)
            .modifier(SectionCard())
            
            // MARK: Animation
            FezDivider(label: "Animation")
            
            // Live FPS card
            HStack(spacing: cardSpacing) {
                VStack(spacing: 5) {
                    Text("\(bleController.fez.FPS)")
                        .bold()
                        .monospacedDigit()
                        .frame(width: 80, height: 40)
                        .lineLimit(1)
                        .font(.system(size: 300))
                        .minimumScaleFactor(.leastNonzeroMagnitude)
                    Text("FPS")
                        .frame(height: 15)
                        .lineLimit(1)
                        .font(.system(size: 300))
                        .minimumScaleFactor(.leastNonzeroMagnitude)
                }
                .frame(height: 60)
                .modifier(SectionCard())

                // Animation routine selection card
                HStack {
                    Text("Routine: ")
                    Menu {
                        ForEach(bleController.fez.routines.sorted(by: {$0.value.label > $1.value.label}), id: \.key) { key, value in
                            Button(action: {
                                self.bleController.write( FezCommand(fx: String(key)))
                                bleController.fez.currentRoutine   = value
                                bleController.fez.customHueToggle  = false
                                bleController.fez.selectedHue      = Float(value.defaultHue)
                                bleController.fez.rainbowToggle    = value.defaultRainbowToggle
                                bleController.fez.text             = value.defaultText
                                bleController.fez.targetBrightness = Float(value.idealBrightness)
                            }) {
                                if( key == bleController.fez.currentRoutine?.key ?? unknownRoutine.label) {
                                    Label(value.label, systemImage: "checkmark")
                                } else {
                                    Label(value.label, systemImage: "checkmark").labelStyle(.titleOnly)
                                }
                            }
                        }
                    } label: {
                        Text(bleController.fez.currentRoutine?.label ?? unknownRoutine.label)
                            .frame(maxWidth: .infinity)
                    }
                    .pickerStyle(.menu)
                    .padding(7)
                    .overlay( RoundedRectangle(cornerRadius: 7)
                                .stroke(lineWidth: 1)
                                .foregroundColor(.gray))
                }
                .frame(height: 60)
                .modifier(SectionCard())
                
            }
            
            // MARK: Controls
            FezDivider(label: "Controls")
            
            // Control custom hue and rainbow modes
            VStack(spacing: cardSpacing) {
                HStack(spacing: cardSpacing) {
                    HStack {
                        Text("Custom Hue")
                            .foregroundColor(bleController.fez.customHueToggle ? .green : .gray)
                            .lineLimit(1)
                            .scaledToFill()
                            .minimumScaleFactor(.leastNonzeroMagnitude)
                            .frame(maxWidth: .infinity)
                        Toggle("Color", isOn: customHueToggleBinding)
                            .labelsHidden()
                    }
                    .padding()
                    .overlay( RoundedRectangle(cornerRadius: 15)
                                .stroke(lineWidth: 2)
                                .foregroundColor(bleController.fez.customHueToggle ? .green : .gray))
                    HStack {
                        Text("Rainbow")
                            .foregroundColor(bleController.fez.rainbowToggle ? .green : .gray)
                            .lineLimit(1)
                            .scaledToFill()
                            .minimumScaleFactor(.leastNonzeroMagnitude)
                            .frame(maxWidth: .infinity)
                        Toggle("Rainbow", isOn: rainbowToggleBinding)
                            .labelsHidden()
                    }
                    .padding()
                    .overlay( RoundedRectangle(cornerRadius: 15)
                                .stroke(lineWidth: 2)
                                .foregroundColor(bleController.fez.rainbowToggle ? .green : .gray))
                }
                HueSlider(selectedHue: selectedHueBinding)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .padding(.leading)
                    .padding(.trailing)
            }
            .modifier(SectionCard())
            
            // onEditingChanged() provided by SwiftUIX
            TextField("Custom Message...", text: $customText, onEditingChanged: {
                if( $0 == false ) { // false means editing is completed
                    self.bleController.write( FezCommand(text: self.customText))
                }
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .modifier(TextFieldClearButton(text: $customText))
            .multilineTextAlignment(.leading)
            .modifier(SectionCard())
            .keyboardObserving()
            
        }
        .padding()
        .blur(radius: isSyncing.wrappedValue ? 4 : 0)
        .alert(isPresented: isSyncing) {
            Alert(
                title: Text("Connecting to \(self.bleController.currentPeripheral!.name)"),
                message: Text("Press Cancel to abort"),
                dismissButton: .default(Text("Cancel")) { self.bleController.stopConnect() }
            )
        }
    }
}

struct Fez_Previews: PreviewProvider {
    static let bleController = BLEController()
    
    static var previews: some View {
        VStack {
            Text("Adult Fez Finder")
                .font(.headline)
            Fez()
                .environmentObject(bleController)
        }
    }
}
