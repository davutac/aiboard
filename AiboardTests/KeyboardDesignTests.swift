import AppKit
import SwiftUI
import Testing

@testable import Aiboard

// MARK: - KeyboardDesignTests
struct KeyboardDesignTests {
    // MARK: - Flat Profile Colors
    @Test @MainActor func importedColorsPreserveComponentsAndUseFallbackOnlyWhenMissing() throws {
        let components = PanelEditorColorComponents(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.75)
        let color = KeyboardDesign.Palette.imported(components, fallback: .white)
        let nativeColor = try #require(NSColor(color).usingColorSpace(.sRGB))

        #expect(abs(nativeColor.redComponent - components.red) < 0.001)
        #expect(abs(nativeColor.greenComponent - components.green) < 0.001)
        #expect(abs(nativeColor.blueComponent - components.blue) < 0.001)
        #expect(abs(nativeColor.alphaComponent - components.alpha) < 0.001)
        #expect(KeyboardDesign.Palette.imported(nil, fallback: .white) == .white)
    }

    @Test(arguments: [false, true]) @MainActor
    func keySurfaceKeepsUniformProfileFillWhenActive(isActive: Bool) throws {
        let components = PanelEditorColorComponents(red: 0.12, green: 0.52, blue: 0.9, alpha: 1)
        let renderer = ImageRenderer(
            content:
                KeycapSurface(
                    shape: Rectangle(),
                    fill: KeyboardDesign.Palette.imported(components, fallback: .white),
                    isActive: isActive
                )
                .frame(width: 60, height: 60)
        )
        let image = try #require(renderer.nsImage)
        let imageData = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: imageData))
        let swatchRenderer = ImageRenderer(
            content: Color(.sRGB, red: 0.12, green: 0.52, blue: 0.9)
                .frame(width: 60, height: 60)
        )
        let swatchImage = try #require(swatchRenderer.nsImage)
        let swatchData = try #require(swatchImage.tiffRepresentation)
        let swatch = try #require(NSBitmapImageRep(data: swatchData))
        let expected = try #require(swatch.colorAt(x: 30, y: 30)?.usingColorSpace(.sRGB))

        for y in [10, 30, 50] {
            let pixel = try #require(bitmap.colorAt(x: 30, y: y)?.usingColorSpace(.sRGB))
            #expect(abs(pixel.redComponent - expected.redComponent) < 0.001)
            #expect(abs(pixel.greenComponent - expected.greenComponent) < 0.001)
            #expect(abs(pixel.blueComponent - expected.blueComponent) < 0.001)
        }
    }

    // MARK: - Adaptive Colors
    @Test @MainActor func keyColorsAdaptToAppearanceAndKeepReadableContrast() throws {
        var backgrounds: [CGFloat] = []
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try #require(NSAppearance(named: name))
            var label: NSColor?
            var background: NSColor?
            appearance.performAsCurrentDrawingAppearance {
                label = NSColor(named: "KeyboardLabel")?.usingColorSpace(.sRGB)
                background = NSColor(named: "KeyboardKeyFill")?.usingColorSpace(.sRGB)
            }
            let labelLuminance = luminance(try #require(label))
            let backgroundLuminance = luminance(try #require(background))
            let contrast =
                (max(labelLuminance, backgroundLuminance) + 0.05)
                / (min(labelLuminance, backgroundLuminance) + 0.05)
            #expect(contrast >= 4.5)
            backgrounds.append(backgroundLuminance)
        }
        #expect(backgrounds[0] > backgrounds[1])
    }

    // MARK: - Return Key Geometry
    @Test func roundedReturnKeyPreservesTheNotchAndBounds() {
        let bounds = CGRect(x: 10, y: 20, width: 46, height: 77)
        let path = PanelEditorKeyShape(buttonShape: .isoReturn, cornerRadius: 6).path(in: bounds)

        #expect(path.boundingRect == bounds)
        #expect(path.contains(CGPoint(x: 14, y: 40)))
        #expect(!path.contains(CGPoint(x: 14, y: 80)))
        #expect(path.contains(CGPoint(x: 30, y: 80)))
        #expect(!path.contains(CGPoint(x: 10.1, y: 20.1)))
    }

    // MARK: - Contrast
    private func luminance(_ color: NSColor) -> CGFloat {
        let components = [color.redComponent, color.greenComponent, color.blueComponent].map {
            $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4)
        }
        return components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
    }
}
