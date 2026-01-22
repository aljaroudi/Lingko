//
//  PlatformTypes.swift
//  Lingko
//
//  Platform abstraction layer for cross-platform types
//

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
typealias PlatformColor = UIColor
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
typealias PlatformColor = NSColor
#endif

// MARK: - PlatformImage Extensions
extension PlatformImage {
    var platformCGImage: CGImage? {
        #if os(iOS)
        return self.cgImage
        #elseif os(macOS)
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }

    func platformPNGData() -> Data? {
        #if os(iOS)
        return self.pngData()
        #elseif os(macOS)
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmapImage.representation(using: .png, properties: [:])
        #endif
    }
}

// MARK: - PlatformColor Extensions
extension PlatformColor {
    static var platformLabel: PlatformColor {
        #if os(iOS)
        return .label
        #elseif os(macOS)
        return .labelColor
        #endif
    }

    static var platformSecondaryLabel: PlatformColor {
        #if os(iOS)
        return .secondaryLabel
        #elseif os(macOS)
        return .secondaryLabelColor
        #endif
    }

    static var platformBackground: PlatformColor {
        #if os(iOS)
        return .systemBackground
        #elseif os(macOS)
        return .windowBackgroundColor
        #endif
    }

    static var platformGroupedBackground: PlatformColor {
        #if os(iOS)
        return .systemGroupedBackground
        #elseif os(macOS)
        return .controlBackgroundColor
        #endif
    }
}

// MARK: - SwiftUI Color Extensions
import SwiftUI

extension Color {
    static var platformGroupedBackground: Color {
        #if os(iOS)
        return Color(.systemGroupedBackground)
        #elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var platformBackground: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var platformSecondaryBackground: Color {
        #if os(iOS)
        return Color(.secondarySystemBackground)
        #elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
