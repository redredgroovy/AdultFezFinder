//
//  ActivityIndicator.swift
//  AdultFezFinder
//
//  Created by Derek Moore on 7/21/20.
//  Copyright © 2020 Derek Moore. All rights reserved.
//

import SwiftUI

// Wrapper for old UIKit UIActivityIndicatorView
struct ActivityIndicator: UIViewRepresentable {
    @Binding var show: Bool
    
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        return UIActivityIndicatorView(style: .large)
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        if self.show {
            uiView.startAnimating()
        } else {
            uiView.stopAnimating()
        }
    }
}

struct ActivityIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ActivityIndicator(show: .constant(true))
    }
}
