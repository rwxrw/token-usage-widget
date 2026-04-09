import AppKit
import CoreGraphics

enum MenuBarIcon {
    /// Draws a 20×16 pt arc gauge image for the status item.
    /// `isTemplate` is false so colour is preserved in both light and dark modes.
    static func image(fraction: Double) -> NSImage {
        let size = NSSize(width: 22, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let cx: CGFloat  = rect.midX
            let cy: CGFloat  = rect.midY - 0.5
            let radius: CGFloat = 6.5
            let lineW: CGFloat  = 1.8

            // Arc spans 240° starting from bottom-left (210°) to bottom-right (330°)
            // CG angles: 0 = 3 o'clock, measured counter-clockwise in flipped=false coords
            // We want a "U-opening-up" gauge: start at 210°, end at 330° (clockwise draw)
            let startDeg: CGFloat = 210   // degrees in standard math convention
            let sweepDeg: CGFloat = 240

            let startRad = startDeg * .pi / 180
            let endRad   = (startDeg - sweepDeg) * .pi / 180   // clockwise = subtract

            ctx.setLineWidth(lineW)
            ctx.setLineCap(.round)

            // Track (dim)
            ctx.setStrokeColor(NSColor.tertiaryLabelColor.cgColor)
            ctx.addArc(center: CGPoint(x: cx, y: cy),
                       radius: radius,
                       startAngle: startRad,
                       endAngle: endRad,
                       clockwise: true)
            ctx.strokePath()

            // Filled arc
            let clampedFraction = max(0, min(1, fraction))
            if clampedFraction > 0 {
                let filledEndRad = startRad - (sweepDeg * .pi / 180) * CGFloat(clampedFraction)
                ctx.setStrokeColor(nsGaugeColor(fraction: clampedFraction).cgColor)
                ctx.addArc(center: CGPoint(x: cx, y: cy),
                           radius: radius,
                           startAngle: startRad,
                           endAngle: filledEndRad,
                           clockwise: true)
                ctx.strokePath()
            }

            return true
        }
        image.isTemplate = false
        return image
    }

    private static func nsGaugeColor(fraction: Double) -> NSColor {
        switch fraction {
        case ..<0.6:
            return NSColor(red: 0.15, green: 0.75, blue: 0.25, alpha: 1)
        case ..<0.85:
            let t = CGFloat((fraction - 0.6) / 0.25)
            return NSColor(red: 0.15 + 0.85 * t, green: 0.75 - 0.20 * t, blue: 0.0, alpha: 1)
        default:
            let t = CGFloat((fraction - 0.85) / 0.15)
            return NSColor(red: 1.0, green: 0.55 - 0.55 * t, blue: 0.0, alpha: 1)
        }
    }
}
