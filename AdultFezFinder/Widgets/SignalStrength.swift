//
//  SignalStrength.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/21/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import SwiftUI

struct Divided<S: Shape>: Shape {
    var amount: CGFloat // Should be in range 0...1
    var shape: S
    func path(in rect: CGRect) -> Path {
        shape.path(in: rect.divided(atDistance: amount * rect.height, from: .maxYEdge).slice)
    }
}

extension Shape {
    func divided(amount: CGFloat) -> Divided<Self> {
        return Divided(amount: amount, shape: self)
    }
}

struct SignalStrengthBars: View {
    var rssi: Int
    
    // color() and bars() may need to be updated if this changes
    private let totalBars: Int = 4
    
    // These are totally arbitrary thresholds
    var bars: Int {
        if rssi >= -50 {
            return 4
        } else if rssi >= -65 {
            return 3
        } else if rssi >= -80 {
            return 2
        } else {
            return 1
        }
    }
    
    var color: Color {
        if bars >= 3 {
            return Color.green
        } else if bars >= 2 {
            return Color.orange
        } else {
            return Color.red
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: geometry.size.width * 0.07) {
                ForEach(0..<self.totalBars) { bar in
                    RoundedRectangle(cornerRadius: 2)
                        .divided(amount: (CGFloat(bar) + 1) / CGFloat(self.totalBars))
                        .fill(bar < self.bars ? self.color : Color.primary.opacity(0.1))
                }
            }
        }
    }
}

struct SignalStrengthLabel: View {
    var rssi: Int
    
    var body: some View {
        Text("\(rssi) dB")
            .lineLimit(1)
            .font(.system(size: 300))
            .minimumScaleFactor(.leastNonzeroMagnitude)
            .padding(0)
    }
}

struct SignalStrength_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            SignalStrengthBars(rssi: -95)
                .frame(width: 30, height: 30)
            SignalStrengthBars(rssi: -75)
                .frame(width: 30 , height: 30)
            SignalStrengthBars(rssi: -55)
                .frame(width: 30 , height: 30)
            HStack {
                Text("NN").hidden().overlay(SignalStrengthBars(rssi: -35))
                SignalStrengthLabel(rssi: -35)
                    .frame(height: 30)
            }
        }
    }
}

