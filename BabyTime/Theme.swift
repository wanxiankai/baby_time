import SwiftUI

enum BabyTimeTheme {
    static let coral = Color(red: 0.92, green: 0.42, blue: 0.34)
    static let coralSoft = Color(red: 0.98, green: 0.76, blue: 0.65)
    static let teal = Color(red: 0.18, green: 0.47, blue: 0.50)
    static let tealSoft = Color(red: 0.75, green: 0.88, blue: 0.86)
    static let cream = Color(red: 1.00, green: 0.96, blue: 0.88)
    static let butter = Color(red: 0.98, green: 0.82, blue: 0.42)
    static let ink = Color(red: 0.12, green: 0.20, blue: 0.22)
    static let card = Color(red: 1.00, green: 0.985, blue: 0.95)
    static let page = Color(red: 0.99, green: 0.955, blue: 0.90)
    static let border = Color(red: 0.87, green: 0.72, blue: 0.58).opacity(0.35)

    static let heroGradient = LinearGradient(
        colors: [cream, tealSoft.opacity(0.55), coralSoft.opacity(0.45)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let buttonGradient = LinearGradient(
        colors: [coral, teal],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct PrimaryBabyTimeButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(BabyTimeTheme.buttonGradient, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
