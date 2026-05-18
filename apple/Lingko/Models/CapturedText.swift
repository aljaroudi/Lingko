//
//  CapturedText.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import CoreGraphics

struct CapturedText: Identifiable, Sendable {
    let id: UUID
    let text: String
    let confidence: Float
    let boundingBox: CGRect  // Normalized coordinates (0-1)

    init(
        id: UUID = UUID(),
        text: String,
        confidence: Float,
        boundingBox: CGRect
    ) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }

    var isReliable: Bool {
        confidence >= 0.7
    }
}
