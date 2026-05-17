//
//  PlatformTypes.swift
//  Lingko
//
//  Platform abstraction layer for cross-platform types
//

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

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
