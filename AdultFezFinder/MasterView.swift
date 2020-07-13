//
//  MasterView.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/7/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import SwiftUI

struct MasterView: View {
    @EnvironmentObject var fezState: FezState
    @EnvironmentObject var bleController: BLEController

    var body: some View {
        VStack {
            if fezState.peripheral != nil {
                PowerMeter()
            } else if bleController.state.case != .connected {
                BLEScanner()
            }
        }
    }
}

struct MasterView_Previews: PreviewProvider {
    static var previews: some View {
        MasterView()
            .environmentObject(FezState())
            .environmentObject(BLEController())
    }
}
