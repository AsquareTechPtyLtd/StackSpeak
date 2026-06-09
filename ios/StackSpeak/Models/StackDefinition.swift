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
    /// Topical grouping for the stack picker. Tolerant: unknown/missing → `.other`.
    let category: StackTopic

    private enum CodingKeys: String, CodingKey {
        case id, name, file, wordCount, description, icon, minimumLevel, isMandatory, category
    }

    init(id: String, name: String, file: String, wordCount: Int, description: String,
         icon: String, minimumLevel: Int, isMandatory: Bool, category: StackTopic = .other) {
        self.id = id
        self.name = name
        self.file = file
        self.wordCount = wordCount
        self.description = description
        self.icon = icon
        self.minimumLevel = minimumLevel
        self.isMandatory = isMandatory
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        file = try c.decode(String.self, forKey: .file)
        wordCount = try c.decode(Int.self, forKey: .wordCount)
        description = try c.decode(String.self, forKey: .description)
        icon = try c.decode(String.self, forKey: .icon)
        minimumLevel = try c.decode(Int.self, forKey: .minimumLevel)
        isMandatory = try c.decode(Bool.self, forKey: .isMandatory)
        let raw = try c.decodeIfPresent(String.self, forKey: .category)
        category = raw.flatMap(StackTopic.init(rawValue:)) ?? .other
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(file, forKey: .file)
        try c.encode(wordCount, forKey: .wordCount)
        try c.encode(description, forKey: .description)
        try c.encode(icon, forKey: .icon)
        try c.encode(minimumLevel, forKey: .minimumLevel)
        try c.encode(isMandatory, forKey: .isMandatory)
        try c.encode(category, forKey: .category)
    }
}

struct StacksIndex: Codable {
    let version: String
    let stacks: [StackDefinition]
}
