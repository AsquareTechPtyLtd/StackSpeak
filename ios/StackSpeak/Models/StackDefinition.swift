import Foundation

struct StackDefinition: Codable, Identifiable {
    let id: String
    let name: String
    let file: String
    let wordCount: Int
    let description: String
    let icon: String
    let minimumLevel: Int
    let isMandatory: Bool
}

struct StacksIndex: Codable {
    let version: String
    let stacks: [StackDefinition]
}
