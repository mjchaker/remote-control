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
            // Set a comfortable minimum; the window can grow from here and the
            // touch surface expands to fill the extra space.
            .frame(minWidth: 360, idealWidth: 400, minHeight: 600, idealHeight: 680)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
