import Foundation
import SwiftData

@Model
final class Word: Codable {
    @Attribute(.unique) var id: UUID
    var word: String
    var pronunciation: String
    var partOfSpeech: String
    var shortDefinition: String
    var longDefinition: String
    var techContext: String
    var exampleSentence: String
    var etymology: String
    var codeExampleLanguage: String
    var codeExampleCode: String
    var stack: WordStack
    var unlockLevel: Int
    var tags: [String]

    init(
        id: UUID,
        word: String,
        pronunciation: String,
        partOfSpeech: String,
        shortDefinition: String,
        longDefinition: String,
        techContext: String,
        exampleSentence: String,
        etymology: String,
        codeExampleLanguage: String,
        codeExampleCode: String,
        stack: WordStack,
        unlockLevel: Int,
        tags: [String]
    ) {
        self.id = id
        self.word = word
        self.pronunciation = pronunciation
        self.partOfSpeech = partOfSpeech
        self.shortDefinition = shortDefinition
        self.longDefinition = longDefinition
        self.techContext = techContext
        self.exampleSentence = exampleSentence
        self.etymology = etymology
        self.codeExampleLanguage = codeExampleLanguage
        self.codeExampleCode = codeExampleCode
        self.stack = stack
        self.unlockLevel = unlockLevel
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id, word, pronunciation, partOfSpeech, shortDefinition
        case longDefinition, techContext, exampleSentence, etymology
        case codeExample, stack, unlockLevel, tags
    }

    enum CodeExampleKeys: String, CodingKey {
        case language, code
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        word = try container.decode(String.self, forKey: .word)
        pronunciation = try container.decode(String.self, forKey: .pronunciation)
        partOfSpeech = try container.decode(String.self, forKey: .partOfSpeech)
        shortDefinition = try container.decode(String.self, forKey: .shortDefinition)
        longDefinition = try container.decode(String.self, forKey: .longDefinition)
        techContext = try container.decode(String.self, forKey: .techContext)
        exampleSentence = try container.decode(String.self, forKey: .exampleSentence)
        etymology = try container.decode(String.self, forKey: .etymology)
        stack = try container.decode(WordStack.self, forKey: .stack)
        unlockLevel = try container.decode(Int.self, forKey: .unlockLevel)
        tags = try container.decode([String].self, forKey: .tags)

        let codeExampleContainer = try container.nestedContainer(keyedBy: CodeExampleKeys.self, forKey: .codeExample)
        codeExampleLanguage = try codeExampleContainer.decode(String.self, forKey: .language)
        codeExampleCode = try codeExampleContainer.decode(String.self, forKey: .code)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(word, forKey: .word)
        try container.encode(pronunciation, forKey: .pronunciation)
        try container.encode(partOfSpeech, forKey: .partOfSpeech)
        try container.encode(shortDefinition, forKey: .shortDefinition)
        try container.encode(longDefinition, forKey: .longDefinition)
        try container.encode(techContext, forKey: .techContext)
        try container.encode(exampleSentence, forKey: .exampleSentence)
        try container.encode(etymology, forKey: .etymology)
        try container.encode(stack, forKey: .stack)
        try container.encode(unlockLevel, forKey: .unlockLevel)
        try container.encode(tags, forKey: .tags)

        var codeExampleContainer = container.nestedContainer(keyedBy: CodeExampleKeys.self, forKey: .codeExample)
        try codeExampleContainer.encode(codeExampleLanguage, forKey: .language)
        try codeExampleContainer.encode(codeExampleCode, forKey: .code)
    }
}

enum WordStack: String, Codable, CaseIterable, Identifiable {
    case basicProgramming = "basic-programming"
    case basicWeb = "basic-web"
    case codeQuality = "code-quality"
    case engineeringCulture = "engineering-culture"
    case basicFrontend = "basic-frontend"
    case basicBackend = "basic-backend"

    case basicNetworking = "basic-networking"
    case versionControl = "version-control"
    case testing = "testing"
    case basicMobile = "basic-mobile"

    case architecture = "architecture"
    case basicSystemDesign = "basic-system-design"
    case performance = "performance"
    case advancedFrontend = "advanced-frontend"
    case advancedBackend = "advanced-backend"
    case mobile = "mobile"
    case security = "security"

    case advancedSystemDesign = "advanced-system-design"
    case advancedNetworking = "advanced-networking"
    case interview = "interview"
    case leadership = "leadership"
    case devops = "devops"
    case dataEngineering = "data-engineering"

    case architectureAtScale = "architecture-at-scale"
    case machineLearning = "machine-learning"
    case securityArchitecture = "security-architecture"
    case dataPlatform = "data-platform"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .basicProgramming: return "Basic Programming"
        case .basicWeb: return "Basic Web"
        case .codeQuality: return "Code Quality"
        case .engineeringCulture: return "Engineering Culture"
        case .basicFrontend: return "Basic Frontend"
        case .basicBackend: return "Basic Backend"
        case .basicNetworking: return "Basic Networking"
        case .versionControl: return "Version Control"
        case .testing: return "Testing"
        case .basicMobile: return "Basic Mobile"
        case .architecture: return "Architecture"
        case .basicSystemDesign: return "Basic System Design"
        case .performance: return "Performance"
        case .advancedFrontend: return "Advanced Frontend"
        case .advancedBackend: return "Advanced Backend"
        case .mobile: return "Mobile"
        case .security: return "Security"
        case .advancedSystemDesign: return "Advanced System Design"
        case .advancedNetworking: return "Advanced Networking"
        case .interview: return "Interview"
        case .leadership: return "Leadership"
        case .devops: return "DevOps"
        case .dataEngineering: return "Data Engineering"
        case .architectureAtScale: return "Architecture at Scale"
        case .machineLearning: return "Machine Learning"
        case .securityArchitecture: return "Security Architecture"
        case .dataPlatform: return "Data Platform"
        }
    }

    var description: String {
        switch self {
        case .basicProgramming: return "Variables, functions, loops, and fundamental data structures"
        case .basicWeb: return "HTTP, APIs, JSON, and REST basics"
        case .codeQuality: return "Readability, naming conventions, and simple patterns"
        case .engineeringCulture: return "Code reviews, pull requests, and team collaboration"
        case .basicFrontend: return "HTML, CSS, JavaScript, and DOM fundamentals"
        case .basicBackend: return "Databases, servers, and API design basics"
        case .basicNetworking: return "DNS, TCP/IP, HTTP, and request/response cycles"
        case .versionControl: return "Git workflows, branches, merges, and collaboration"
        case .testing: return "Unit tests, integration tests, and TDD basics"
        case .basicMobile: return "Mobile app fundamentals and native vs cross-platform"
        case .architecture: return "SOLID principles, design patterns, and modularity"
        case .basicSystemDesign: return "Caching, load balancing, and basic scaling"
        case .performance: return "Profiling, optimization, and identifying bottlenecks"
        case .advancedFrontend: return "State management, SSR, build tools, and frameworks"
        case .advancedBackend: return "Microservices, message queues, and event-driven patterns"
        case .mobile: return "Advanced mobile patterns, native development, and app lifecycle"
        case .security: return "Authentication, authorization, OWASP, and threat modeling"
        case .advancedSystemDesign: return "Distributed systems, CAP theorem, and consistency models"
        case .advancedNetworking: return "Load balancers, CDNs, edge computing, and routing"
        case .interview: return "Technical interview vocabulary and problem-solving terms"
        case .leadership: return "Technical decisions, mentoring, and RFC writing"
        case .devops: return "CI/CD, infrastructure as code, containers, and orchestration"
        case .dataEngineering: return "ETL pipelines, data warehousing, and streaming"
        case .architectureAtScale: return "Multi-region systems, platform thinking, and org-scale design"
        case .machineLearning: return "Model terminology, training, inference, and embeddings"
        case .securityArchitecture: return "Security architecture, compliance, and zero-trust design"
        case .dataPlatform: return "Data platform architecture, governance, and analytics"
        }
    }

    var icon: String {
        switch self {
        case .basicProgramming: return "chevron.left.forwardslash.chevron.right"
        case .basicWeb: return "globe"
        case .codeQuality: return "checkmark.seal"
        case .engineeringCulture: return "person.3"
        case .basicFrontend: return "paintbrush"
        case .basicBackend: return "server.rack"
        case .basicNetworking: return "network"
        case .versionControl: return "arrow.triangle.branch"
        case .testing: return "testtube.2"
        case .basicMobile: return "iphone"
        case .architecture: return "building.2"
        case .basicSystemDesign: return "square.grid.3x3"
        case .performance: return "speedometer"
        case .advancedFrontend: return "paintbrush.pointed"
        case .advancedBackend: return "externaldrive.connected.to.line.below"
        case .mobile: return "iphone.gen3"
        case .security: return "lock.shield"
        case .advancedSystemDesign: return "square.grid.3x3.fill"
        case .advancedNetworking: return "cloud.fill"
        case .interview: return "person.bubble"
        case .leadership: return "star.circle"
        case .devops: return "gearshape.2"
        case .dataEngineering: return "cylinder.split.1x2"
        case .architectureAtScale: return "building.columns"
        case .machineLearning: return "brain"
        case .securityArchitecture: return "lock.rectangle.stack"
        case .dataPlatform: return "chart.bar.doc.horizontal"
        }
    }

    var minimumLevel: Int {
        switch self {
        case .basicProgramming, .basicWeb, .codeQuality, .engineeringCulture:
            return 1
        case .basicNetworking, .versionControl, .testing:
            return 2
        case .architecture, .basicSystemDesign, .performance:
            return 3
        case .advancedSystemDesign, .advancedNetworking, .interview:
            return 4
        case .leadership, .architectureAtScale:
            return 5
        default:
            return 1
        }
    }

    var isMandatoryAtLevel: Bool {
        switch self {
        case .basicProgramming, .basicWeb, .codeQuality, .engineeringCulture,
             .basicNetworking, .versionControl, .testing,
             .architecture, .basicSystemDesign, .performance,
             .advancedSystemDesign, .advancedNetworking, .interview,
             .leadership, .architectureAtScale:
            return true
        default:
            return false
        }
    }

    static func mandatoryStacks(for level: Int) -> Set<WordStack> {
        Set(allCases.filter { $0.isMandatoryAtLevel && $0.minimumLevel <= level })
    }

    static func newMandatoryStacks(for level: Int) -> Set<WordStack> {
        Set(allCases.filter { $0.isMandatoryAtLevel && $0.minimumLevel == level })
    }

    static func availableOptionalStacks(for level: Int) -> Set<WordStack> {
        Set(allCases.filter { !$0.isMandatoryAtLevel && $0.minimumLevel <= level })
    }

    static func newOptionalStacks(for level: Int) -> Set<WordStack> {
        Set(allCases.filter { !$0.isMandatoryAtLevel && $0.minimumLevel == level })
    }
}

struct WordsDatabase: Codable {
    let words: [Word]
}
