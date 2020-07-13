//
//  PowerMeter.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/9/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import SwiftUI

struct PowerMeterBar: View {
    @EnvironmentObject var fezState: FezState
    
    let powerFade = LinearGradient(
        gradient: Gradient(colors: [.green, .green, .yellow, .red]),
        startPoint: .leading,
        endPoint: .trailing)

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(UIColor.systemGray5))
                    .overlay(Rectangle()
                        .size(width: CGFloat(self.fezState.maCapacity)*geometry.size.width, height: geometry.size.height)
                        .fill(self.powerFade)
                        .animation(.easeOut(duration: 0.3))
                ).cornerRadius(5)
            }
        }
    }
}

struct PowerMeterLabel: View {
    @EnvironmentObject var fezState: FezState
    
    var body: some View {
        Text("\(self.fezState.maDraw, specifier: "%5.2f") A")
            .font(.system(.body, design: .monospaced))
            .bold()
            .multilineTextAlignment(.trailing)
            .minimumScaleFactor(.leastNonzeroMagnitude)
    }
}

struct PowerMeter: View {
    var body: some View {
        HStack {
            PowerMeterBar()
            PowerMeterLabel()
       }
    }
}

struct PowerMeter_Previews: View {
    @EnvironmentObject var fezState: FezState
    
    var body: some View {
        VStack {
            PowerMeter()
                .frame(height: 10)
            PowerMeter()
                .frame(height: 15)
            PowerMeter()
                .frame(height: 20)
            Slider(value: Binding<Float>(
                get: { self.fezState.maDraw },
                set: { self.fezState.maDraw = $0 }
            ), in: -5...35)
        }.padding()
    }
}

struct PowerMeter_Previews_Container: PreviewProvider {
    static let fezState = FezState()
    static var previews: some View {
        PowerMeter_Previews().environmentObject(fezState)
    }
}
