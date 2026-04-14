import Foundation

/// Key codes matching lg_keymap.py exactly (42LW5700-class legacy HDCP HandleKeyInput).
enum LGKey: String, CaseIterable {
    // Channel / volume / power
    case chUp    = "CH+"
    case chDown  = "CH-"
    case volUp   = "VOL+"
    case volDown = "VOL-"
    case power   = "POWER"
    case mute    = "MUTE"
    // Inputs
    case input   = "INPUT"
    case tvRad   = "TV_RAD"
    // Digits
    case n0 = "0", n1 = "1", n2 = "2", n3 = "3", n4 = "4"
    case n5 = "5", n6 = "6", n7 = "7", n8 = "8", n9 = "9"
    case list   = "LIST"
    case qView  = "Q_VIEW"
    case fav    = "FAV"
    case text   = "TEXT"
    case tOpt   = "T_OPT"
    case back   = "BACK"
    // Navigation
    case right  = "RIGHT"
    case left   = "LEFT"
    case up     = "UP"
    case down   = "DOWN"
    case ok     = "OK"
    case exit   = "EXIT"
    // Menu / portal
    case menu      = "MENU"
    case quickMenu = "QUICK_MENU"
    case home      = "HOME"
    case guide     = "GUIDE"
    case info      = "INFO"
    // Colors
    case blue   = "BLUE"
    case yellow = "YELLOW"
    case green  = "GREEN"
    case red    = "RED"
    // Picture / sound
    case ratio    = "RATIO"
    case subtitle = "SUBTITLE"
    case ad       = "AD"
    case threeD   = "3D"
    // Playback
    case ff     = "FF"
    case rew    = "REW"
    case play   = "PLAY"
    case stop   = "STOP"
    case pause  = "PAUSE"
    case rec    = "REC"
    case simLink = "SIM_LINK"

    var code: Int {
        switch self {
        case .chUp:    return 0
        case .chDown:  return 1
        case .volUp:   return 2
        case .volDown: return 3
        case .power:   return 8
        case .mute:    return 9
        case .input:   return 11
        case .tvRad:   return 15
        case .n0:      return 16
        case .n1:      return 17
        case .n2:      return 18
        case .n3:      return 19
        case .n4:      return 20
        case .n5:      return 21
        case .n6:      return 22
        case .n7:      return 23
        case .n8:      return 24
        case .n9:      return 25
        case .list:    return 26
        case .qView:   return 27
        case .fav:     return 30
        case .text:    return 32
        case .tOpt:    return 33
        case .subtitle: return 57
        case .back:    return 40
        case .right:   return 6
        case .left:    return 7
        case .up:      return 64
        case .down:    return 65
        case .menu:    return 67
        case .ok:      return 68
        case .quickMenu: return 69
        case .home:    return 89
        case .exit:    return 91
        case .ratio:   return 121
        case .ff:      return 142
        case .rew:     return 143
        case .ad:      return 145
        case .guide:   return 169
        case .info:    return 170
        case .play:    return 176
        case .stop:    return 177
        case .pause:   return 186
        case .rec:     return 189
        case .simLink: return 126
        case .blue:    return 97
        case .yellow:  return 99
        case .green:   return 113
        case .red:     return 114
        case .threeD:  return 220
        }
    }
}
