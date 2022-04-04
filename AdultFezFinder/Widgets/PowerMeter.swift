//
//  PowerMeter.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/9/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import SwiftUI
import UIKit

import DSFSparkline
import XCGLogger

struct PowerMeterBar: View {
    var capacity: Float
    
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
                        .size(width: CGFloat(self.capacity)*geometry.size.width, height: geometry.size.height)
                        .fill(self.powerFade)
                        .animation(.easeOut(duration: 0.1))
                )
            }
        }
    }
}

struct VPowerMeterBar: View {
    var capacity: Float
    
    let powerFade = LinearGradient(
        gradient: Gradient(colors: [.green, .green, .yellow, .red]),
        startPoint: .bottom,
        endPoint: .top)

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(self.powerFade)
                    .overlay(Rectangle()
                        .size(width: geometry.size.width, height: geometry.size.height - (CGFloat(self.capacity) * geometry.size.height))
                        .fill(Color(UIColor.systemGray5))
                        .animation(Animation.easeOut(duration: 0.1))
                    )
            }
        }
    }
}

struct PowerMeterLabel: View {
    @EnvironmentObject var fezState: FezState
    
    var body: some View {
        Text("\(self.fezState.currentDraw, specifier: "%5.2f") A")
            .font(.system(.body, design: .monospaced))
            .bold()
            .multilineTextAlignment(.trailing)
            .minimumScaleFactor(.leastNonzeroMagnitude)
    }
}

struct PowerMeter: View {
    var capacity: Float

    var body: some View {
        HStack {
            PowerMeterBar(capacity: capacity)
            PowerMeterLabel()
       }
    }
}

struct PowerMeterSpark: View {
    var source: DSFSparkline.DataSource
    
    var sparkOverlay: DSFSparklineOverlay {
        get {
            let red = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 0.0, 0.0, 1.0])!
            let yellow = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.0, 1.0])!
            let green = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 1.0, 0.0, 1.0])!
            
            let lineOverlay = DSFSparklineOverlay.Line()
            lineOverlay.dataSource = source
            
            lineOverlay.primaryFill = DSFSparkline.Fill.Gradient(colors: [red, yellow, green, green])
            lineOverlay.strokeWidth = 1
            
            return lineOverlay
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            DSFSparklineSurface.SwiftUI([sparkOverlay])
                .frame(width: geometry.size.width, height: geometry.size.height)
                .animation(Animation.easeOut(duration: 0.1))
        }
    }
}

struct PowerMeter_Previews: View {
    @EnvironmentObject var fezState: FezState

    @State var powerDraw = Float(0.0)
    
    let testDataSource = DSFSparkline.DataSource(range: 0.0 ... 1.0)

    var body: some View {
        VStack {
            VPowerMeterBar(capacity: powerDraw)
                .frame(width: 10, height: 60)
            PowerMeterSpark(source: testDataSource)
                .frame(width: 200, height: 50)
            PowerMeter(capacity: powerDraw)
                .frame(height: 10)
            PowerMeter(capacity: powerDraw)
                .frame(height: 15)
            PowerMeter(capacity: powerDraw)
                .frame(height: 20)
            Slider(value: Binding<Float>(
                get: { self.powerDraw },
                set: {
                    self.powerDraw = $0
                    self.testDataSource.push(value: CGFloat($0))
                }
            ), in: 0.0 ... 1.0)
        }.padding()
    }
}


struct PowerMeter_Previews_Container: PreviewProvider {
    static let fezState = FezState()
    static var previews: some View {
        PowerMeter_Previews().environmentObject(fezState)
    }
}

