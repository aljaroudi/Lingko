//
//  PlatformUtils.swift
//  Lingko
//
//  Platform-specific utility functions
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PlatformUtils {
    static func copyToPasteboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    static func readFromPasteboard() -> String? {
        #if os(iOS)
        return UIPasteboard.general.string
        #elseif os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #endif
    }

}
