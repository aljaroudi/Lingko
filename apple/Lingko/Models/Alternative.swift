//
//  Alternative.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation

struct Alternative: Identifiable, Codable, Sendable {
    let id: UUID
    let text: String
    let explanation: String // Why/when to use this version
    let formalityLevel: FormalityLevel

    init(
        id: UUID = UUID(),
        text: String,
        explanation: String,
        formalityLevel: FormalityLevel
    ) {
        self.id = id
        self.text = text
        self.explanation = explanation
        self.formalityLevel = formalityLevel
    }
}
