//
//  Command.swift
//  MacRemote
//
//  Universal command model for controlling the Mac
//

import Foundation

/// Universal command that works across all control types
enum UniversalCommand: Equatable {
    case media(MediaAction)
    case volume(VolumeAction)
    case navigation(NavigationAction)
    case system(SystemAction)
}

/// Media playback actions
enum MediaAction: String, CaseIterable {
    case playPause = "Play/Pause"
    case next = "Next Track"
    case previous = "Previous Track"
    case fastForward = "Fast Forward"
    case rewind = "Rewind"

    var systemImageName: String {
        switch self {
        case .playPause: return "playpause.fill"
        case .next: return "forward.fill"
        case .previous: return "backward.fill"
        case .fastForward: return "forward.end.fill"
        case .rewind: return "backward.end.fill"
        }
    }
}

/// Volume control actions
enum VolumeAction: String, CaseIterable {
    case up = "Volume Up"
    case down = "Volume Down"
    case mute = "Mute/Unmute"
    case setLevel = "Set Level"

    var systemImageName: String {
        switch self {
        case .up: return "speaker.wave.3.fill"
        case .down: return "speaker.wave.1.fill"
        case .mute: return "speaker.slash.fill"
        case .setLevel: return "speaker.2.fill"
        }
    }
}

/// Navigation actions for gesture control
enum NavigationAction: Equatable {
    case up
    case down
    case left
    case right
    case select
    case back
    case scroll(dx: CGFloat, dy: CGFloat)

    var description: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .select: return "Select"
        case .back: return "Back"
        case .scroll: return "Scroll"
        }
    }
}

/// System-level actions
enum SystemAction: String, CaseIterable {
    case brightnessUp = "Brightness Up"
    case brightnessDown = "Brightness Down"
    case sleep = "Sleep"
    case lock = "Lock Screen"

    var systemImageName: String {
        switch self {
        case .brightnessUp: return "sun.max.fill"
        case .brightnessDown: return "sun.min.fill"
        case .sleep: return "power"
        case .lock: return "lock.fill"
        }
    }
}
