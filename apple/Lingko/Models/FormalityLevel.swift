//
//  FormalityLevel.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation

enum FormalityLevel: String, Codable, CaseIterable, Sendable {
    case veryFormal = "Very Formal"
    case formal = "Formal"
    case neutral = "Neutral"
    case informal = "Informal"
    case veryInformal = "Very Informal"

    /// SF Symbol icon representing this formality level
    var icon: String {
        switch self {
        case .veryFormal: return "suit.fill"
        case .formal: return "briefcase.fill"
        case .neutral: return "circle.fill"
        case .informal: return "bubble.left.fill"
        case .veryInformal: return "hands.sparkles.fill"
        }
    }

    /// Short description for UI display
    var description: String {
        rawValue
    }
}
