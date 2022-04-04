//
//  HueSlider.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 2/13/22.
//  Copyright © 2022 Derek Moore. All rights reserved.
//

import SwiftUI

struct HueSlider: View {
    @Binding var selectedHue: Float

    @State private var isDragging: Bool = false
    @State private var sliderPos: CGFloat = 0.0
    @State private var hueIndex: Int = 0
    
    var colors: [Color] = {
        let hueValues = Array(0...359)
        return hueValues.map {
            Color(UIColor(hue: CGFloat($0) / 359.0,
                          saturation: 1.0,
                          brightness: 1.0,
                          alpha: 1.0))
        }
    }()
    
    var circleWidth: CGFloat {
        isDragging ? 70 : 40
    }
    
    var body: some View {
        VStack {
            ZStack {
                GeometryReader { geometry in
                    LinearGradient(gradient: Gradient(colors: colors),
                               startPoint: .leading,
                               endPoint: .trailing)
                        .gesture(
                            DragGesture()
                                .onChanged {
                                    self.isDragging = true
                                    var rawPos = $0.startLocation.x + $0.translation.width
                                    rawPos = max(rawPos, 0)
                                    self.sliderPos = min(geometry.size.width, rawPos)
                                    self.selectedHue = Float(self.sliderPos / geometry.size.width * 359)
                                }
                                .onEnded { _ in
                                    self.isDragging = false
                                    //self.selectedHue = self.hueIndex
                                }
                        )
                        .frame(height: 40)
                        .cornerRadius(8)
    
                    Circle()
                        .foregroundColor(colors[Int(self.selectedHue)])
                        .allowsHitTesting(false)
                        .frame(width: self.circleWidth, height: self.circleWidth, alignment: .center)
                        .shadow(radius: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: self.circleWidth / 2.0).stroke(Color.white, lineWidth: 2.0)
                        )
                        .offset(x: (CGFloat(self.selectedHue) / 359 * geometry.size.width) - (self.circleWidth/2),
                                y: self.isDragging ? -self.circleWidth : 0.0)
                        .animation(Animation.spring().speed(2))
                }
            }
        }
    }
}
//.offset(x: self.sliderPos - (self.circleWidth/2), y: self.isDragging ? -self.circleWidth : 0.0)

struct HueSlider_Previews: View {
    @State var hue: Float = 0.0
    var body: some View {
        VStack {
            HueSlider(selectedHue: $hue)
                .frame(width: 300)
            Text(String(hue))
        }
    }
}

struct HueSlider_Previews_Container: PreviewProvider {
    static var previews: some View {
        HueSlider_Previews()
    }
}
