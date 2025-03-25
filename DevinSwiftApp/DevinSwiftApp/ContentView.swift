//
//  ContentView.swift
//  DevinSwiftApp
//
//  Created by David N. Junod on 3/25/25.
//

import SwiftUI

struct ContentView: View {
    @State private var rotationDegrees = 0.0
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .rotationEffect(Angle(degrees: rotationDegrees))
                .animation(.linear(duration: 5).repeatForever(autoreverses: false), value: rotationDegrees)
                .onAppear {
                    rotationDegrees = 360.0
                }
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
