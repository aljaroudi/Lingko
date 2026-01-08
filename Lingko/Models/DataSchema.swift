//
//  DataSchema.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import SwiftData

typealias DataSchema = DataSchemaV1
typealias Item = DataSchema.Item

enum DataSchemaV1: VersionedSchema {
    static var models: [any PersistentModel.Type] { [
         self.Item.self,
    ] }

    static let versionIdentifier = Schema.Version(1, 0, 0)

    @Model
    final class Item {
        var timestamp: Date

        init(timestamp: Date) {
            self.timestamp = timestamp
        }
    }
}
