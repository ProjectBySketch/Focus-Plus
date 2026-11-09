//
//  AppLogo.swift
//  Focus Plus
//

import SwiftUI

/// The Focus Plus mark, drawn rather than loaded: a minimal aperture ring with
/// a four-point spark inside it, in the accent colour the user picked — so it
/// follows Purple by default and every other theme after that.
enum AppLogoStyle {
    /// The mark on its own, stroked in the accent colour.
    case mark
    /// The mark on a rounded accent tile, the way it appears on a Home Screen.
    case tile
}

struct AppLogo: View {
    var style: AppLogoStyle = .mark
    var size: CGFloat = 22
    /// Overrides the accent — used where the background is already accent-tinted.
    var tint: Color? = nil

    private var color: Color { tint ?? Theme.accent }

    var body: some View {
        Group {
            switch style {
            case .mark:
                mark
                    .frame(width: size, height: size)
                    .foregroundStyle(color)
            case .tile:
                tile
            }
        }
        .accessibilityHidden(true)
    }

    private var mark: some View {
        FocusMark()
            .stroke(
                style: StrokeStyle(
                    lineWidth: max(1.2, size * 0.09),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
    }

    private var tile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.95), color.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            FocusMark()
                .stroke(
                    style: StrokeStyle(
                        lineWidth: max(1.4, size * 0.075),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: size * 0.62, height: size * 0.62)
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14))
        )
        .shadow(color: color.opacity(0.35), radius: size * 0.28, y: size * 0.1)
    }
}

/// An aperture ring with a spark in the middle: the whole mark in one path, so
/// it stays crisp at any size.
struct FocusMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let centre = CGPoint(x: rect.midX, y: rect.midY)

        // Outer ring.
        let ringInset = radius * 0.16
        path.addEllipse(in: rect.insetBy(dx: ringInset, dy: ringInset))

        // The spark: four concave points reaching just inside the ring.
        let spark = radius * 0.46
        let waist = radius * 0.10
        let top = CGPoint(x: centre.x, y: centre.y - spark)
        let right = CGPoint(x: centre.x + spark, y: centre.y)
        let bottom = CGPoint(x: centre.x, y: centre.y + spark)
        let left = CGPoint(x: centre.x - spark, y: centre.y)
        let control = CGPoint(x: centre.x, y: centre.y)

        path.move(to: top)
        path.addQuadCurve(to: right, control: CGPoint(x: centre.x + waist, y: centre.y - waist))
        path.addQuadCurve(to: bottom, control: CGPoint(x: centre.x + waist, y: centre.y + waist))
        path.addQuadCurve(to: left, control: CGPoint(x: centre.x - waist, y: centre.y + waist))
        path.addQuadCurve(to: top, control: CGPoint(x: centre.x - waist, y: centre.y - waist))
        _ = control

        return path
    }
}
