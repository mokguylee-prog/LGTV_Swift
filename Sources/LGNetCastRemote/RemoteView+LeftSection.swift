import SwiftUI

// MARK: - Left section (width = 158)

extension RemoteView {

    var leftSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            utilityRow
            numberPad
            sideGroup
        }
        .frame(width: 158)
    }

    // Utility row: RATIO / INPUT / TV
    var utilityRow: some View {
        let items: [(String, Int)] = [
            ("RATIO", K.RATIO),
            ("INPUT", K.INPUT),
            ("TV",    K.TV_RAD),
        ]
        return HStack(alignment: .center, spacing: 0) {
            ForEach(0..<3, id: \.self) { idx in
                CircleBtn(
                    label: items[idx].0, code: items[idx].1,
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

    // Number pad: 1-9 grid + PREV / 0 / Q.VIEW row
    var numberPad: some View {
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
            HStack(alignment: .center, spacing: 0) {
                SkinBtn(label: "PREV",   code: K.LIST,
                        width: lw3[0], height: 30,
                        bg: .lightBg, fg: .lightFg,
                        border: .lightBorder, activeBg: .lightActiveBg, fontSize: 8)
                gap(lGap)
                SkinBtn(label: "0",      code: K.n0,
                        width: lw3[1], height: 40,
                        bg: .lightBg, fg: .lightFg,
                        border: .lightBorder, activeBg: .lightActiveBg, fontSize: 14)
                gap(lGap)
                SkinBtn(label: "Q.VIEW", code: K.Q_VIEW,
                        width: lw3[2], height: 30,
                        bg: .lightBg, fg: .lightFg,
                        border: .lightBorder, activeBg: .lightActiveBg, fontSize: 8)
            }
        }
        .padding(.bottom, 15)
    }

    // Side group: VOL (tall blue) | FAV+MUTE | CH (tall blue)
    var sideGroup: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 2) {
                SkinBtn(label: "VOL+", code: K.VOL_UP,
                        width: lw3[0], height: 95,
                        bg: .sideBg, fg: .sideFg,
                        border: .sideBorder, activeBg: .sideActiveBg, fontSize: 12)
                SkinBtn(label: "VOL-", code: K.VOL_DOWN,
                        width: lw3[0], height: 95,
                        bg: .sideBg, fg: .sideFg,
                        border: .sideBorder, activeBg: .sideActiveBg, fontSize: 12)
            }
            .frame(width: lw3[0])
            gap(lGap)

            VStack(spacing: 2) {
                SkinBtn(label: "FAV",  code: K.FAV,
                        width: lw3[1], height: 26,
                        bg: .lightBg, fg: .lightFg,
                        border: .lightBorder, activeBg: .lightActiveBg, fontSize: 8)
                SkinBtn(label: "MUTE", code: K.MUTE,
                        width: lw3[1], height: 162,
                        bg: .lightBg, fg: .lightFg,
                        border: .lightBorder, activeBg: .lightActiveBg, fontSize: 10)
            }
            .frame(width: lw3[1])
            gap(lGap)

            VStack(spacing: 2) {
                SkinBtn(label: "CH+", code: K.CH_UP,
                        width: lw3[2], height: 95,
                        bg: .sideBg, fg: .sideFg,
                        border: .sideBorder, activeBg: .sideActiveBg, fontSize: 12)
                SkinBtn(label: "CH-", code: K.CH_DOWN,
                        width: lw3[2], height: 95,
                        bg: .sideBg, fg: .sideFg,
                        border: .sideBorder, activeBg: .sideActiveBg, fontSize: 12)
            }
            .frame(width: lw3[2])
        }
        .padding(.bottom, 10)
    }
}
