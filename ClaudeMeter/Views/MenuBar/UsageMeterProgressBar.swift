import SwiftUI

struct UsageMeterProgressBar: View {
    let percentage: Double
    var color: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(UsageStatus.trackColor)

                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(percentage, 0) / 100, 1.0))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct UsagePacingIndicator: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(compact ? .caption2 : .caption)
            if !compact {
                Text("At risk")
                    .font(.caption.weight(.medium))
            }
        }
        .foregroundStyle(Color(nsColor: .systemOrange))
        .help("Usage is outpacing this window. You may hit the limit before it resets.")
        .accessibilityLabel("At risk of hitting the limit before reset")
    }
}
