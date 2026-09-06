import SwiftUI

// MARK: - PanelEditorISOEnterMetrics
nonisolated enum PanelEditorISOEnterMetrics {
    nonisolated static let lowerLeadingInsetFraction: CGFloat = 8 / 46
    nonisolated static let upperHeightFraction: CGFloat = 37 / 77
}

// MARK: - PanelEditorKeyShape
struct PanelEditorKeyShape: Shape {
    let buttonShape: PanelEditorButtonShape
    var cornerRadius: CGFloat = 0

    // MARK: - Path
    nonisolated func path(in rect: CGRect) -> Path {
        switch buttonShape {
        case .rectangle:
            return Path(roundedRect: rect, cornerRadius: cornerRadius)
        case .isoReturn:
            let lowerLeadingInset =
                rect.width * PanelEditorISOEnterMetrics.lowerLeadingInsetFraction
            let upperSectionHeight =
                rect.height * PanelEditorISOEnterMetrics.upperHeightFraction
            let corners = [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY),
                CGPoint(x: rect.minX + lowerLeadingInset, y: rect.maxY),
                CGPoint(x: rect.minX + lowerLeadingInset, y: rect.minY + upperSectionHeight),
                CGPoint(x: rect.minX, y: rect.minY + upperSectionHeight),
            ]
            var path = Path()
            if cornerRadius > 0 {
                path.move(to: CGPoint(x: rect.minX, y: rect.minY + upperSectionHeight / 2))
                for index in corners.indices {
                    path.addArc(
                        tangent1End: corners[index],
                        tangent2End: corners[(index + 1) % corners.count],
                        radius: min(cornerRadius, lowerLeadingInset / 2)
                    )
                }
            }
            else {
                path.move(to: corners[0])
                for corner in corners.dropFirst() {
                    path.addLine(to: corner)
                }
            }
            path.closeSubpath()
            return path
        }
    }
}
