//
//  CapturedText.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import CoreGraphics
import VisionKit

/// Represents text captured from camera or image with positional information
struct CapturedText: Identifiable, Sendable {
    let id: UUID
    let text: String
    let confidence: Float
    let boundingBox: CGRect  // Normalized coordinates (0-1)
    let detectedLanguage: String?

    init(
        id: UUID = UUID(),
        text: String,
        confidence: Float,
        boundingBox: CGRect,
        detectedLanguage: String? = nil
    ) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.detectedLanguage = detectedLanguage
    }

    /// Confidence as percentage
    var confidencePercentage: String {
        String(format: "%.0f%%", confidence * 100)
    }

    /// Whether confidence is high enough for reliable translation
    var isReliable: Bool {
        confidence >= 0.7
    }
}
