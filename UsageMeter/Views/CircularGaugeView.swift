import SwiftUI

struct CircularGaugeView: View {
    let fraction: Double
    let diameter: CGFloat

    private var strokeWidth: CGFloat { diameter * 0.09 }

    // 270° arc: starts at bottom-left (225°) sweeps clockwise to bottom-right (315°)
    // In SwiftUI, 0° = 3 o'clock, angles increase clockwise
    private let startAngle = Angle.degrees(135)   // top-left (225° std math = 135° SwiftUI)
    private let totalSweep = 270.0

    var body: some View {
        ZStack {
            // Track
            ArcShape(startAngle: startAngle, endAngle: .degrees(135 + totalSweep), clockwise: true)
                .stroke(
                    Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )

            // Fill
            ArcShape(
                startAngle: startAngle,
                endAngle: .degrees(135 + totalSweep * max(0, min(1, fraction))),
                clockwise: true
            )
            .stroke(
                Color.gauge(fraction: fraction),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
            )
            .animation(.spring(response: 0.7, dampingFraction: 0.8), value: fraction)

            // Centre label
            VStack(spacing: 1) {
                Text("\(Int(fraction * 100))%")
                    .font(.system(size: diameter * 0.22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("used")
                    .font(.system(size: diameter * 0.11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - ArcShape

struct ArcShape: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var clockwise: Bool

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.degrees, endAngle.degrees) }
        set { startAngle = .degrees(newValue.first); endAngle = .degrees(newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: !clockwise   // SwiftUI uses flipped y axis
        )
        return p
    }
}
