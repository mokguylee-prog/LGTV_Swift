import SwiftUI
import AppKit

// MARK: - WheelView (top-level container)

struct WheelView: View {
    @EnvironmentObject var tv: TVController
    @State private var version:   Int    = 1
    @State private var sliderVal: Double = 0.75

    private var friction: CGFloat { CGFloat(0.90 + sliderVal * 0.09) }

    var body: some View {
        VStack(spacing: 0) {
            // Version picker
            HStack(spacing: 4) {
                ForEach([1, 2], id: \.self) { v in
                    Button("V\(v)") {
                        withAnimation(.easeInOut(duration: 0.2)) { version = v }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 44, height: 24)
                    .background(version == v ? Color(white: 0.28) : Color(white: 0.14))
                    .foregroundColor(version == v ? .white : Color(white: 0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)

            Spacer()

            if version == 1 {
                HStack(alignment: .center, spacing: 0) {
                    FrictionSlider(value: $sliderVal)
                        .frame(width: 46, height: 220)
                        .padding(.leading, 8)
                    Spacer()
                    CylinderWheelControl(label: "소리", upKey: .volUp, downKey: .volDown,
                                         friction: friction)
                    Spacer()
                    CylinderWheelControl(label: "채널", upKey: .chUp,  downKey: .chDown,
                                         friction: friction)
                    Spacer()
                }
            } else {
                HStack(spacing: 0) {
                    Spacer()
                    DialWheelControl(label: "소리", upKey: .volUp, downKey: .volDown)
                    Spacer()
                    DialWheelControl(label: "채널", upKey: .chUp,  downKey: .chDown)
                    Spacer()
                }
            }

            Spacer()
        }
        .frame(width: 418, height: 560)
        .background(Color(hex: "0d0d0d"))
    }
}
