//
//  NamedEntity.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import NaturalLanguage
import SwiftUI

/// A named entity extracted from text (person, place, organization)
struct NamedEntity: Identifiable, Sendable {
    let id: UUID
    let text: String
    let type: NLTag

    init(id: UUID = UUID(), text: String, type: NLTag) {
        self.id = id
        self.text = text
        self.type = type
    }

    /// Human-readable description of the entity type
    var typeDescription: String {
        switch type {
        case .personalName:
            return "Person"
        case .placeName:
            return "Place"
        case .organizationName:
            return "Organization"
        default:
            return "Entity"
        }
    }

    /// SF Symbol icon for the entity type
    var icon: String {
        switch type {
        case .personalName:
            return "person.fill"
        case .placeName:
            return "mappin.circle.fill"
        case .organizationName:
            return "building.2.fill"
        default:
            return "tag.fill"
        }
    }

    /// Color for the entity type
    var color: Color {
        switch type {
        case .personalName:
            return .blue
        case .placeName:
            return .green
        case .organizationName:
            return .purple
        default:
            return .gray
        }
    }
}
