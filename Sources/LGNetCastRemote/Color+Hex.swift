import SwiftUI

// MARK: - Hex Color initializer (shared across all views)

extension Color {
    /// Initialize from a hex string: "#FF0000" or "FF0000"
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

    /// Named-label variant for callers that use `hex:` label.
    init(hex: String) { self.init(hex) }
}
