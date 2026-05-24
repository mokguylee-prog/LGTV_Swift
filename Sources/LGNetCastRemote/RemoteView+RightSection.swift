import SwiftUI

// MARK: - Right section (width = 260)

extension RemoteView {

    var rightSection: some View {
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

    // Nav pad: SL/UP/3D | LEFT/OK/RIGHT | HOME/DOWN
    var navShell: some View {
        VStack(spacing: 2) {
            HStack(spacing: rGap) {
                SkinBtn(label: "SL",   code: K.SIM_LINK,
                        width: navSide,   height: 30,
                        bg: .darkBg, fg: .darkFg, border: .darkBorder, activeBg: .darkActiveBg, fontSize: 10)
                SkinBtn(label: "UP",   code: K.UP,
                        width: navCenter, height: 30,
                        bg: .grayBg, fg: .white,  border: .grayBorder, activeBg: .grayActiveBg, fontSize: 12)
                SkinBtn(label: "3D",   code: K.THREE_D,
                        width: navSide,   height: 30,
                        bg: .darkBg, fg: .darkFg, border: .darkBorder, activeBg: .darkActiveBg, fontSize: 10)
            }
            HStack(spacing: rGap) {
                SkinBtn(label: "LEFT",  code: K.LEFT,
                        width: navSide,   height: 45,
                        bg: .grayBg, fg: .white, border: .grayBorder, activeBg: .grayActiveBg, fontSize: 10)
                SkinBtn(label: "OK",    code: K.OK,
                        width: navCenter, height: 45,
                        bg: .grayBg, fg: .white, border: .grayBorder, activeBg: .grayActiveBg, fontSize: 14)
                SkinBtn(label: "RIGHT", code: K.RIGHT,
                        width: navSide,   height: 45,
                        bg: .grayBg, fg: .white, border: .grayBorder, activeBg: .grayActiveBg, fontSize: 10)
            }
            HStack(spacing: rGap) {
                SkinBtn(label: "HOME", code: K.MENU,
                        width: navSide,   height: 30,
                        bg: .darkBg, fg: .darkFg, border: .darkBorder, activeBg: .darkActiveBg, fontSize: 9)
                SkinBtn(label: "DOWN", code: K.DOWN,
                        width: navCenter, height: 30,
                        bg: .grayBg, fg: .white,  border: .grayBorder, activeBg: .grayActiveBg, fontSize: 12)
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

    // BACK / GUIDE / EXIT
    var guideRow: some View {
        HStack(spacing: 0) {
            let items: [(String, Int, CGFloat)] = [
                ("BACK",  K.BACK,  82),
                ("GUIDE", K.GUIDE, 96),
                ("EXIT",  K.EXIT,  82),
            ]
            ForEach(0..<3, id: \.self) { idx in
                SkinBtn(label: items[idx].0, code: items[idx].1,
                        width: items[idx].2, height: 35,
                        bg: .darkBg, fg: .darkFg, border: .darkBorder, activeBg: .darkActiveBg)
                if idx < 2 { gap(rGap) }
            }
        }
        .padding(.bottom, 10)
    }

    // R / G / Y / B
    var colorRow: some View {
        HStack(spacing: 0) {
            let items: [(String, Int, Color)] = [
                ("R", K.RED,    Color("#c23836")),
                ("G", K.GREEN,  Color("#1ca85e")),
                ("Y", K.YELLOW, Color("#e0b640")),
                ("B", K.BLUE,   Color("#3b72c3")),
            ]
            ForEach(0..<4, id: \.self) { idx in
                SkinBtn(label: items[idx].0, code: items[idx].1,
                        width: rw4[idx], height: 25,
                        bg: items[idx].2, fg: .white,
                        border: items[idx].2, activeBg: items[idx].2)
                if idx < 3 { gap(rGap) }
            }
        }
        .padding(.bottom, 10)
    }

    // TEXT / T.OPT / SUB / Q.MENU
    var serviceRow: some View {
        HStack(spacing: 0) {
            let items: [(String, Int)] = [
                ("TEXT", K.TEXT), ("T.OPT", K.T_OPT),
                ("SUB",  K.SUBTITLE), ("Q.MENU", K.QUICK_MENU),
            ]
            ForEach(0..<4, id: \.self) { idx in
                SkinBtn(label: items[idx].0, code: items[idx].1,
                        width: rw4[idx], height: 30,
                        bg: .darkBg, fg: .darkFg, border: .darkBorder,
                        activeBg: .darkActiveBg, fontSize: 9)
                if idx < 3 { gap(rGap) }
            }
        }
        .padding(.bottom, 10)
    }

    // << / > / || / [] / >>
    var mediaRow: some View {
        HStack(spacing: 0) {
            let items: [(String, Int)] = [
                ("<<", K.REW), (">", K.PLAY), ("||", K.PAUSE),
                ("[]", K.STOP), (">>", K.FF),
            ]
            ForEach(0..<5, id: \.self) { idx in
                SkinBtn(label: items[idx].0, code: items[idx].1,
                        width: rw5[idx], height: 30,
                        bg: .darkBg, fg: .darkFg, border: .darkBorder,
                        activeBg: .darkActiveBg, fontSize: 11)
                if idx < 4 { gap(rGap) }
            }
        }
        .padding(.bottom, 10)
    }

    // INFO / AD / APP/*
    var bottomRow: some View {
        HStack(spacing: 0) {
            let items: [(String, Int)] = [
                ("INFO", K.INFO), ("AD", K.AD), ("APP/*", K.HOME),
            ]
            ForEach(0..<3, id: \.self) { idx in
                SkinBtn(label: items[idx].0, code: items[idx].1,
                        width: rw3[idx], height: 30,
                        bg: .darkBg, fg: .darkFg, border: .darkBorder,
                        activeBg: .darkActiveBg, fontSize: 9)
                if idx < 2 { gap(rGap) }
            }
        }
        .padding(.bottom, 10)
    }

    // Full-width REC button
    var recRow: some View {
        SkinBtn(
            label: "● REC", code: K.REC,
            width: 260, height: 30,
            bg: Color("#c23836"), fg: .white,
            border: Color("#c23836"), activeBg: Color("#a02e2b"),
            fontSize: 12
        )
    }
}
