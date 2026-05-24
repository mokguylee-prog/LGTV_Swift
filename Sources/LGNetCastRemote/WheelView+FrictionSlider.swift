import SwiftUI

// MARK: - Friction slider (vertical, controls coast decay)

struct FrictionSlider: View {
    @Binding var value: Double
    private let thumbH: CGFloat = 20

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 2) {
                Image(systemName: "hare.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.35, green: 0.65, blue: 1.0))
                Text("부드럽게")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(Color(white: 0.55))
            }

            GeometryReader { geo in
                let h     = geo.size.height
                let range = max(h - thumbH, 1)
                let ty    = CGFloat(1.0 - value) * range

                ZStack(alignment: .top) {
                    // Track
                    Capsule()
                        .fill(Color(white: 0.13))
                        .overlay(Capsule().stroke(Color(white: 0.30), lineWidth: 0.5))
                        .frame(width: 5).frame(maxWidth: .infinity)
                        .padding(.vertical, thumbH / 2)

                    // Fill above thumb
                    if ty > thumbH / 2 {
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.25, green: 0.55, blue: 1.0),
                                         Color(red: 0.14, green: 0.36, blue: 0.84)],
                                startPoint: .top, endPoint: .bottom))
                            .frame(width: 5, height: ty - thumbH / 2)
                            .frame(maxWidth: .infinity)
                            .padding(.top, thumbH / 2)
                    }

                    // Thumb
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [Color(white: 0.82), Color(white: 0.54)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 24, height: thumbH)
                            .overlay(RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(red: 0.30, green: 0.60, blue: 1.0), lineWidth: 1.4))
                            .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
                        VStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { _ in
                                Capsule().fill(Color(white: 0.36)).frame(width: 14, height: 1.5)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .offset(y: ty)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    let raw = 1.0 - Double(drag.location.y - thumbH / 2) / Double(range)
                    value = max(0, min(1, raw))
                })
            }

            VStack(spacing: 2) {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.40))
                Text("뻑뻑")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(Color(white: 0.40))
            }
        }
    }
}
