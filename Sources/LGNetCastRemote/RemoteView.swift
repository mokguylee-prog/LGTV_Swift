import SwiftUI

// MARK: - Hex Color (private to this file)

private extension Color {
    init(_ hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8)  & 0xFF) / 255,
            blue:  Double( v        & 0xFF) / 255
        )
    }

    // ── Palette (matches WPF RemoteWindow.xaml) ───────────────────────────
    static let appBg          = Color("#202020")
    static let bodyBg         = Color("#070707")
    static let innerBg        = Color("#111111")
    static let edge           = Color("#2c2c2c")

    static let lightBg        = Color("#f0efe8")
    static let lightActiveBg  = Color("#e0ddd3")
    static let lightFg        = Color("#222222")
    static let lightBorder    = Color("#575757")

    static let darkBg         = Color("#171717")
    static let darkActiveBg   = Color("#262626")
    static let darkFg         = Color("#f1f1f1")
    static let darkBorder     = Color("#303030")

    static let sideBg         = Color("#78a4eb")
    static let sideActiveBg   = Color("#638fd6")
    static let sideFg         = Color("#132235")
    static let sideBorder     = Color("#47699e")

    static let grayBg         = Color("#808080")
    static let grayActiveBg   = Color("#666666")
    static let grayBorder     = Color("#606060")

    static let captionFg      = Color("#b9b9b9")
    static let logoFg         = Color("#ebebeb")
}

// MARK: - Key codes

private enum K {
    static let CH_UP = 0,  CH_DOWN = 1, VOL_UP = 2,  VOL_DOWN = 3
    static let POWER = 8,  MUTE    = 9
    static let INPUT = 11, TV_RAD  = 15
    static let n0 = 16, n1 = 17, n2 = 18, n3 = 19, n4 = 20
    static let n5 = 21, n6 = 22, n7 = 23, n8 = 24, n9 = 25
    static let LIST = 26, Q_VIEW = 27
    static let FAV = 30
    static let TEXT = 32, T_OPT = 33
    static let SUBTITLE = 57
    static let BACK  = 40
    static let RIGHT = 6,  LEFT  = 7,  UP  = 64, DOWN = 65
    static let MENU  = 67, OK    = 68, QUICK_MENU = 69
    static let HOME  = 89, EXIT  = 91
    static let RATIO = 121
    static let FF    = 142, REW   = 143
    static let AD    = 145
    static let GUIDE = 169, INFO  = 170
    static let PLAY  = 176, STOP  = 177, PAUSE = 186
    static let REC   = 189
    static let RED   = 114, GREEN = 113, YELLOW = 99, BLUE = 97
    static let THREE_D = 220
    static let SIM_LINK = 126
}

// MARK: - Layout constants

private let lGap: CGFloat = 5
private let rGap: CGFloat = 6

private let lw3: [CGFloat] = [49, 49, 50]
private let rw3: [CGFloat] = [82, 82, 84]
private let rw4: [CGFloat] = [60, 60, 60, 62]
private let rw5: [CGFloat] = [47, 47, 47, 47, 48]

private let navSide:   CGFloat = 52
private let navCenter: CGFloat = 124

// MARK: - SkinButton (rounded corners, matching WPF CornerRadius=4)

private struct SkinBtn: View {
    let label:    String
    let code:     Int
    let width:    CGFloat
    let height:   CGFloat
    let bg:       Color
    let fg:       Color
    let border:   Color
    let activeBg: Color
    var fontSize: CGFloat = 10
    var radius:   CGFloat = 4

    @EnvironmentObject var tv: TVController
    @State private var hovered = false

    var body: some View {
        Button { Task { await tv.sendKeyCode(code) } } label: {
            Text(label)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(fg)
                .frame(width: width - 2, height: height - 2)
                .background(hovered ? activeBg : bg)
                .clipShape(RoundedRectangle(cornerRadius: max(radius - 1, 0)))
        }
        .buttonStyle(.plain)
        .frame(width: width, height: height)
        .background(border)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .onHover { hovered = $0 }
    }
}

// MARK: - CircleButton

private struct CircleBtn: View {
    let label:      String
    let code:       Int
    let diameter:   CGFloat
    let fill:       Color
    let textFill:   Color
    let outline:    Color
    let activeFill: Color
    var fontSize:   CGFloat = 11

    @EnvironmentObject var tv: TVController
    @State private var hovered = false

    var body: some View {
        Button { Task { await tv.sendKeyCode(code) } } label: {
            ZStack {
                Circle()
                    .fill(hovered ? activeFill : fill)
                    .overlay(Circle().stroke(outline, lineWidth: 1))
                    .frame(width: diameter - 4, height: diameter - 4)
                Text(label)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(textFill)
            }
        }
        .buttonStyle(.plain)
        .frame(width: diameter, height: diameter)
        .onHover { hovered = $0 }
    }
}

// MARK: - Row helpers

private func gap(_ w: CGFloat) -> some View { Color.clear.frame(width: w) }

// MARK: - RemoteView

struct RemoteView: View {
    @EnvironmentObject var tv: TVController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Compact status bar
            HStack(spacing: 8) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 7, height: 7)
                Text(tv.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    openWindow(id: "connection")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("연결 설정", systemImage: "network.badge.shield.half.filled")
                        .font(.caption)
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        innerContent
                    }
                    .padding(8)
                    .background(Color.bodyBg)
                    .overlay(Rectangle().stroke(Color.edge, lineWidth: 1)
                        .clipShape(RoundedRectangle(cornerRadius: 8)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(Color.appBg)
                .disabled(!tv.connectionState.isConnected)
                .opacity(tv.connectionState.isConnected ? 1 : 0.45)
            }
            .background(Color.appBg)
        }
        .frame(width: 480)
        .background(Color.appBg)
    }

    private var stateColor: Color {
        switch tv.connectionState {
        case .disconnected: return .gray
        case .connecting:   return .orange
        case .connected:    return .green
        case .error:        return .red
        }
    }

    // ── Inner remote body ──────────────────────────────────────────────────

    @ViewBuilder
    private var innerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            powerRow
            HStack(alignment: .top, spacing: 8) {
                leftSection
                rightSection
            }
        }
        .padding(15)
        .background(Color.innerBg)
    }

    // ── Power row ──────────────────────────────────────────────────────────

    private var powerRow: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: PWR circle + MUTE
            HStack(alignment: .top, spacing: 0) {
                CircleBtn(
                    label: "PWR", code: K.POWER, diameter: 54,
                    fill: Color("#c72b24"), textFill: .white,
                    outline: Color("#6a201d"), activeFill: Color("#ab241e"),
                    fontSize: 12
                )
                SkinBtn(
                    label: "MUTE", code: K.MUTE,
                    width: 76, height: 34,
                    bg: .lightBg, fg: .lightFg,
                    border: .lightBorder, activeBg: .lightActiveBg
                )
                .padding(.leading, 15)
                .padding(.top, 10)
            }

            Spacer()

            // Logo (right-aligned) — reference: remocon.png / WPF design
            VStack(alignment: .trailing, spacing: 2) {
                Text("LG")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.logoFg)
                Text("Windows Port")
                    .font(.system(size: 12))
                    .foregroundColor(.captionFg)
            }
            .padding(.top, 4)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Left section (width=158)

    private var leftSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            utilityRow
            numberPad
            sideGroup
        }
        .frame(width: 158)
    }

    // Utility row: RATIO / INPUT / TV — circle buttons with caption
    private var utilityRow: some View {
        let items: [(String, String, Int)] = [
            ("RATIO", "RATIO", K.RATIO),
            ("INPUT", "INPUT", K.INPUT),
            ("TV",    "TV",    K.TV_RAD),
        ]
        return HStack(alignment: .center, spacing: 0) {
            ForEach(0..<3, id: \.self) { idx in
                CircleBtn(
                    label: items[idx].1, code: items[idx].2,
                    diameter: 35,
                    fill: .darkBg, textFill: .darkFg,
                    outline: .darkBorder, activeFill: .darkActiveBg,
                    fontSize: 8
                )
                .frame(width: lw3[idx])
                if idx < 2 { gap(lGap) }
            }
        }
        .padding(.bottom, 10)
    }

    // Number pad: 1-9 grid + PREV/0/Q.VIEW row
    private var numberPad: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    let keys  = [["1","2","3"],["4","5","6"],["7","8","9"]]
                    let codes = [[K.n1,K.n2,K.n3],[K.n4,K.n5,K.n6],[K.n7,K.n8,K.n9]]
                    ForEach(0..<3, id: \.self) { col in
                        SkinBtn(
                            label: keys[row][col], code: codes[row][col],
                            width: lw3[col], height: 40,
                            bg: .lightBg, fg: .lightFg,
                            border: .lightBorder, activeBg: .lightActiveBg,
                            fontSize: 14
                        )
                        if col < 2 { gap(lGap) }
                    }
                }
                .padding(.bottom, 2)
            }
            // Row 4: PREV / 0 / Q.VIEW
            HStack(alignment: .center, spacing: 0) {
                SkinBtn(
                    label: "PREV", code: K.LIST,
                    width: lw3[0], height: 30,
                    bg: .lightBg, fg: .lightFg,
                    border: .lightBorder, activeBg: .lightActiveBg,
                    fontSize: 8
                )
                gap(lGap)
                SkinBtn(
                    label: "0", code: K.n0,
                    width: lw3[1], height: 40,
                    bg: .lightBg, fg: .lightFg,
                    border: .lightBorder, activeBg: .lightActiveBg,
                    fontSize: 14
                )
                gap(lGap)
                SkinBtn(
                    label: "Q.VIEW", code: K.Q_VIEW,
                    width: lw3[2], height: 30,
                    bg: .lightBg, fg: .lightFg,
                    border: .lightBorder, activeBg: .lightActiveBg,
                    fontSize: 8
                )
            }
        }
        .padding(.bottom, 15)
    }

    // Side group: 3 columns — Vol (tall blue) | FAV+MUTE (light) | CH (tall blue)
    private var sideGroup: some View {
        HStack(alignment: .top, spacing: 0) {
            // Volume column
            VStack(spacing: 2) {
                SkinBtn(
                    label: "VOL+", code: K.VOL_UP,
                    width: lw3[0], height: 95,
                    bg: .sideBg, fg: .sideFg,
                    border: .sideBorder, activeBg: .sideActiveBg,
                    fontSize: 12
                )
                SkinBtn(
                    label: "VOL-", code: K.VOL_DOWN,
                    width: lw3[0], height: 95,
                    bg: .sideBg, fg: .sideFg,
                    border: .sideBorder, activeBg: .sideActiveBg,
                    fontSize: 12
                )
            }
            .frame(width: lw3[0])
            gap(lGap)

            // Middle column: FAV (top) + MUTE (remaining)
            VStack(spacing: 2) {
                SkinBtn(
                    label: "FAV", code: K.FAV,
                    width: lw3[1], height: 26,
                    bg: .lightBg, fg: .lightFg,
                    border: .lightBorder, activeBg: .lightActiveBg,
                    fontSize: 8
                )
                SkinBtn(
                    label: "MUTE", code: K.MUTE,
                    width: lw3[1], height: 162,
                    bg: .lightBg, fg: .lightFg,
                    border: .lightBorder, activeBg: .lightActiveBg,
                    fontSize: 10
                )
            }
            .frame(width: lw3[1])
            gap(lGap)

            // Channel column
            VStack(spacing: 2) {
                SkinBtn(
                    label: "CH+", code: K.CH_UP,
                    width: lw3[2], height: 95,
                    bg: .sideBg, fg: .sideFg,
                    border: .sideBorder, activeBg: .sideActiveBg,
                    fontSize: 12
                )
                SkinBtn(
                    label: "CH-", code: K.CH_DOWN,
                    width: lw3[2], height: 95,
                    bg: .sideBg, fg: .sideFg,
                    border: .sideBorder, activeBg: .sideActiveBg,
                    fontSize: 12
                )
            }
            .frame(width: lw3[2])
        }
        .padding(.bottom, 10)
    }

    // MARK: - Right section (width=260)

    private var rightSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            navShell
            guideRow
            colorRow
            serviceRow
            mediaRow
            bottomRow
            recRow
        }
        .frame(width: 260)
    }

    // Nav pad — 3×3 grid matching WPF layout:
    //   SL  | UP(gray)  | 3D
    //   LEFT(gray) | OK(gray) | RIGHT(gray)
    //   HOME | DOWN(gray) | [empty]
    private var navShell: some View {
        VStack(spacing: 2) {
            // Row 0: SL | UP | 3D
            HStack(spacing: rGap) {
                SkinBtn(label: "SL",  code: K.SIM_LINK,
                        width: navSide, height: 30,
                        bg: .darkBg, fg: .darkFg,
                        border: .darkBorder, activeBg: .darkActiveBg,
                        fontSize: 10)
                SkinBtn(label: "UP",  code: K.UP,
                        width: navCenter, height: 30,
                        bg: .grayBg, fg: .white,
                        border: .grayBorder, activeBg: .grayActiveBg,
                        fontSize: 12)
                SkinBtn(label: "3D",  code: K.THREE_D,
                        width: navSide, height: 30,
                        bg: .darkBg, fg: .darkFg,
                        border: .darkBorder, activeBg: .darkActiveBg,
                        fontSize: 10)
            }
            // Row 1: LEFT | OK | RIGHT
            HStack(spacing: rGap) {
                SkinBtn(label: "LEFT",  code: K.LEFT,
                        width: navSide, height: 45,
                        bg: .grayBg, fg: .white,
                        border: .grayBorder, activeBg: .grayActiveBg,
                        fontSize: 10)
                SkinBtn(label: "OK",    code: K.OK,
                        width: navCenter, height: 45,
                        bg: .grayBg, fg: .white,
                        border: .grayBorder, activeBg: .grayActiveBg,
                        fontSize: 14)
                SkinBtn(label: "RIGHT", code: K.RIGHT,
                        width: navSide, height: 45,
                        bg: .grayBg, fg: .white,
                        border: .grayBorder, activeBg: .grayActiveBg,
                        fontSize: 10)
            }
            // Row 2: HOME | DOWN | [empty]
            HStack(spacing: rGap) {
                SkinBtn(label: "HOME", code: K.MENU,
                        width: navSide, height: 30,
                        bg: .darkBg, fg: .darkFg,
                        border: .darkBorder, activeBg: .darkActiveBg,
                        fontSize: 9)
                SkinBtn(label: "DOWN", code: K.DOWN,
                        width: navCenter, height: 30,
                        bg: .grayBg, fg: .white,
                        border: .grayBorder, activeBg: .grayActiveBg,
                        fontSize: 12)
                Color.clear.frame(width: navSide, height: 30)
            }
        }
        .padding(15)
        .frame(width: 260)
        .background(Color("#0b0b0b"))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color("#202020"), lineWidth: 1))
        .padding(.bottom, 15)
    }

    // Guide row: BACK | GUIDE | EXIT
    private var guideRow: some View {
        HStack(spacing: 0) {
            let items: [(String, Int, CGFloat)] = [
                ("BACK",  K.BACK,  82),
                ("GUIDE", K.GUIDE, 96),
                ("EXIT",  K.EXIT,  82),
            ]
            ForEach(0..<3, id: \.self) { idx in
                SkinBtn(
                    label: items[idx].0, code: items[idx].1,
                    width: items[idx].2, height: 35,
                    bg: .darkBg, fg: .darkFg,
                    border: .darkBorder, activeBg: .darkActiveBg
                )
                if idx < 2 { gap(rGap) }
            }
        }
        .padding(.bottom, 10)
    }

    // Color row: R / G / Y / B
    private var colorRow: some View {
        HStack(spacing: 0) {
            let items: [(String, Int, Color)] = [
                ("R", K.RED,    Color("#c23836")),
                ("G", K.GREEN,  Color("#1ca85e")),
                ("Y", K.YELLOW, Color("#e0b640")),
                ("B", K.BLUE,   Color("#3b72c3")),
            ]
            ForEach(0..<4, id: \.self) { idx in
                SkinBtn(
                    label: items[idx].0, code: items[idx].1,
                    width: rw4[idx], height: 25,
                    bg: items[idx].2, fg: .white,
                    border: items[idx].2, activeBg: items[idx].2
                )
                if idx < 3 { gap(rGap) }
            }
        }
        .padding(.bottom, 10)
    }

    // Service row: TEXT / T.OPT / SUB / Q.MENU
    private var serviceRow: some View {
        HStack(spacing: 0) {
            let items: [(String, Int)] = [
                ("TEXT",   K.TEXT),
                ("T.OPT",  K.T_OPT),
                ("SUB",    K.SUBTITLE),
                ("Q.MENU", K.QUICK_MENU),
            ]
            ForEach(0..<4, id: \.self) { idx in
                SkinBtn(
                    label: items[idx].0, code: items[idx].1,
                    width: rw4[idx], height: 30,
                    bg: .darkBg, fg: .darkFg,
                    border: .darkBorder, activeBg: .darkActiveBg,
                    fontSize: 9
                )
                if idx < 3 { gap(rGap) }
            }
        }
        .padding(.bottom, 10)
    }

    // Media row: << / > / || / [] / >>
    private var mediaRow: some View {
        HStack(spacing: 0) {
            let items: [(String, Int)] = [
                ("<<",  K.REW),
                (">",   K.PLAY),
                ("||",  K.PAUSE),
                ("[]",  K.STOP),
                (">>",  K.FF),
            ]
            ForEach(0..<5, id: \.self) { idx in
                SkinBtn(
                    label: items[idx].0, code: items[idx].1,
                    width: rw5[idx], height: 30,
                    bg: .darkBg, fg: .darkFg,
                    border: .darkBorder, activeBg: .darkActiveBg,
                    fontSize: 11
                )
                if idx < 4 { gap(rGap) }
            }
        }
        .padding(.bottom, 10)
    }

    // Bottom row: INFO / AD / APP/*
    private var bottomRow: some View {
        HStack(spacing: 0) {
            let items: [(String, Int)] = [
                ("INFO",  K.INFO),
                ("AD",    K.AD),
                ("APP/*", K.HOME),
            ]
            ForEach(0..<3, id: \.self) { idx in
                SkinBtn(
                    label: items[idx].0, code: items[idx].1,
                    width: rw3[idx], height: 30,
                    bg: .darkBg, fg: .darkFg,
                    border: .darkBorder, activeBg: .darkActiveBg,
                    fontSize: 9
                )
                if idx < 2 { gap(rGap) }
            }
        }
        .padding(.bottom, 10)
    }

    // REC row: full-width red button
    private var recRow: some View {
        SkinBtn(
            label: "● REC", code: K.REC,
            width: 260, height: 30,
            bg: Color("#c23836"), fg: .white,
            border: Color("#c23836"), activeBg: Color("#a02e2b"),
            fontSize: 12
        )
    }
}
