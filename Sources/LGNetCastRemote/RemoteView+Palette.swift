import SwiftUI

// MARK: - Palette (matches WPF RemoteWindow.xaml)

extension Color {
    static let appBg         = Color("#202020")
    static let bodyBg        = Color("#070707")
    static let innerBg       = Color("#111111")
    static let edge          = Color("#2c2c2c")

    static let lightBg       = Color("#f0efe8")
    static let lightActiveBg = Color("#e0ddd3")
    static let lightFg       = Color("#222222")
    static let lightBorder   = Color("#575757")

    static let darkBg        = Color("#171717")
    static let darkActiveBg  = Color("#262626")
    static let darkFg        = Color("#f1f1f1")
    static let darkBorder    = Color("#303030")

    static let sideBg        = Color("#78a4eb")
    static let sideActiveBg  = Color("#638fd6")
    static let sideFg        = Color("#132235")
    static let sideBorder    = Color("#47699e")

    static let grayBg        = Color("#808080")
    static let grayActiveBg  = Color("#666666")
    static let grayBorder    = Color("#606060")

    static let captionFg     = Color("#b9b9b9")
    static let logoFg        = Color("#ebebeb")
}

// MARK: - Key codes

enum K {
    static let CH_UP = 0,  CH_DOWN = 1, VOL_UP = 2,  VOL_DOWN = 3
    static let POWER = 8,  MUTE = 9
    static let INPUT = 11, TV_RAD = 15
    static let n0 = 16, n1 = 17, n2 = 18, n3 = 19, n4 = 20
    static let n5 = 21, n6 = 22, n7 = 23, n8 = 24, n9 = 25
    static let LIST = 26, Q_VIEW = 27
    static let FAV = 30
    static let TEXT = 32, T_OPT = 33
    static let SUBTITLE = 57
    static let BACK  = 40
    static let RIGHT = 6,  LEFT = 7,   UP = 64,  DOWN = 65
    static let MENU  = 67, OK   = 68,  QUICK_MENU = 69
    static let HOME  = 89, EXIT = 91
    static let RATIO = 121
    static let FF    = 142, REW = 143
    static let AD    = 145
    static let GUIDE = 169, INFO = 170
    static let PLAY  = 176, STOP = 177, PAUSE = 186
    static let REC   = 189
    static let RED   = 114, GREEN = 113, YELLOW = 99, BLUE = 97
    static let THREE_D = 220
    static let SIM_LINK = 126
}

// MARK: - Layout constants

let lGap: CGFloat = 5
let rGap: CGFloat = 6

let lw3: [CGFloat] = [49, 49, 50]
let rw3: [CGFloat] = [82, 82, 84]
let rw4: [CGFloat] = [60, 60, 60, 62]
let rw5: [CGFloat] = [47, 47, 47, 47, 48]

let navSide:   CGFloat = 52
let navCenter: CGFloat = 124
