//
//  Tag.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import SwiftUI

/// Represents a tag (category) that can be applied to translation history items
struct TagInfo: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let icon: String
    let color: String?
    let isSystem: Bool
    let sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: String? = nil,
        isSystem: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.isSystem = isSystem
        self.sortOrder = sortOrder
    }

    /// Color for the tag chip
    var chipColor: Color {
        if let color = color {
            return Color(hex: color) ?? .blue
        }
        return .blue
    }
}

// MARK: - Color Extension

extension Color {
    /// Initialize Color from hex string
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Convert Color to hex string
    var hexString: String? {
        #if os(iOS)
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else {
            return nil
        }
        #elseif os(macOS)
        guard let components = NSColor(self).cgColor.components,
              components.count >= 3 else {
            return nil
        }
        #endif

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}
