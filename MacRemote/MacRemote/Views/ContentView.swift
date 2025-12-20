//
//  ContentView.swift
//  MacRemote
//
//  Main content view
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RemoteControlView()
            .frame(minWidth: 400, idealWidth: 450, maxWidth: 500)
            .frame(minHeight: 800, idealHeight: 900, maxHeight: 1000)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
