import Foundation

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

    // MARK: - Metadata (table-driven)

    private static let metadata: [WordStack: WordStackMetadata] = [
        .basicProgramming: WordStackMetadata(
            displayName: "Basic Programming",
            description: "Variables, functions, loops, and fundamental data structures",
            icon: "chevron.left.forwardslash.chevron.right",
            minimumLevel: 1,
            isMandatoryByDefault: true
        ),
        .basicWeb: WordStackMetadata(
            displayName: "Basic Web",
            description: "HTTP, APIs, JSON, and REST basics",
            icon: "globe",
            minimumLevel: 1,
            isMandatoryByDefault: true
        ),
        .codeQuality: WordStackMetadata(
            displayName: "Code Quality",
            description: "Readability, naming conventions, and simple patterns",
            icon: "checkmark.seal",
            minimumLevel: 1,
            isMandatoryByDefault: true
        ),
        .engineeringCulture: WordStackMetadata(
            displayName: "Engineering Culture",
            description: "Code reviews, pull requests, and team collaboration",
            icon: "person.3",
            minimumLevel: 1,
            isMandatoryByDefault: true
        ),
        .basicFrontend: WordStackMetadata(
            displayName: "Basic Frontend",
            description: "HTML, CSS, JavaScript, and DOM fundamentals",
            icon: "paintbrush",
            minimumLevel: 1,
            isMandatoryByDefault: false
        ),
        .basicBackend: WordStackMetadata(
            displayName: "Basic Backend",
            description: "Databases, servers, and API design basics",
            icon: "server.rack",
            minimumLevel: 1,
            isMandatoryByDefault: false
        ),
        .basicNetworking: WordStackMetadata(
            displayName: "Basic Networking",
            description: "DNS, TCP/IP, HTTP, and request/response cycles",
            icon: "network",
            minimumLevel: 2,
            isMandatoryByDefault: true
        ),
        .versionControl: WordStackMetadata(
            displayName: "Version Control",
            description: "Git workflows, branches, merges, and collaboration",
            icon: "arrow.triangle.branch",
            minimumLevel: 2,
            isMandatoryByDefault: true
        ),
        .testing: WordStackMetadata(
            displayName: "Testing",
            description: "Unit tests, integration tests, and TDD basics",
            icon: "testtube.2",
            minimumLevel: 2,
            isMandatoryByDefault: true
        ),
        .basicMobile: WordStackMetadata(
            displayName: "Basic Mobile",
            description: "Mobile app fundamentals and native vs cross-platform",
            icon: "iphone",
            minimumLevel: 2,
            isMandatoryByDefault: false
        ),
        .architecture: WordStackMetadata(
            displayName: "Architecture",
            description: "SOLID principles, design patterns, and modularity",
            icon: "building.2",
            minimumLevel: 3,
            isMandatoryByDefault: true
        ),
        .basicSystemDesign: WordStackMetadata(
            displayName: "Basic System Design",
            description: "Caching, load balancing, and basic scaling",
            icon: "square.grid.3x3",
            minimumLevel: 3,
            isMandatoryByDefault: true
        ),
        .performance: WordStackMetadata(
            displayName: "Performance",
            description: "Profiling, optimization, and identifying bottlenecks",
            icon: "speedometer",
            minimumLevel: 3,
            isMandatoryByDefault: true
        ),
        .advancedFrontend: WordStackMetadata(
            displayName: "Advanced Frontend",
            description: "State management, SSR, build tools, and frameworks",
            icon: "paintbrush.pointed",
            minimumLevel: 3,
            isMandatoryByDefault: false
        ),
        .advancedBackend: WordStackMetadata(
            displayName: "Advanced Backend",
            description: "Microservices, message queues, and event-driven patterns",
            icon: "externaldrive.connected.to.line.below",
            minimumLevel: 3,
            isMandatoryByDefault: false
        ),
        .mobile: WordStackMetadata(
            displayName: "Mobile",
            description: "Advanced mobile patterns, native development, and app lifecycle",
            icon: "iphone.gen3",
            minimumLevel: 3,
            isMandatoryByDefault: false
        ),
        .security: WordStackMetadata(
            displayName: "Security",
            description: "Authentication, authorization, OWASP, and threat modeling",
            icon: "lock.shield",
            minimumLevel: 3,
            isMandatoryByDefault: false
        ),
        .advancedSystemDesign: WordStackMetadata(
            displayName: "Advanced System Design",
            description: "Distributed systems, CAP theorem, and consistency models",
            icon: "square.grid.3x3.fill",
            minimumLevel: 4,
            isMandatoryByDefault: true
        ),
        .advancedNetworking: WordStackMetadata(
            displayName: "Advanced Networking",
            description: "Load balancers, CDNs, edge computing, and routing",
            icon: "cloud.fill",
            minimumLevel: 4,
            isMandatoryByDefault: true
        ),
        .interview: WordStackMetadata(
            displayName: "Interview",
            description: "Technical interview vocabulary and problem-solving terms",
            icon: "person.bubble",
            minimumLevel: 4,
            isMandatoryByDefault: true
        ),
        .devops: WordStackMetadata(
            displayName: "DevOps",
            description: "CI/CD, infrastructure as code, containers, and orchestration",
            icon: "gearshape.2",
            minimumLevel: 4,
            isMandatoryByDefault: false
        ),
        .dataEngineering: WordStackMetadata(
            displayName: "Data Engineering",
            description: "ETL pipelines, data warehousing, and streaming",
            icon: "cylinder.split.1x2",
            minimumLevel: 4,
            isMandatoryByDefault: false
        ),
        .leadership: WordStackMetadata(
            displayName: "Leadership",
            description: "Technical decisions, mentoring, and RFC writing",
            icon: "star.circle",
            minimumLevel: 5,
            isMandatoryByDefault: true
        ),
        .architectureAtScale: WordStackMetadata(
            displayName: "Architecture at Scale",
            description: "Multi-region systems, platform thinking, and org-scale design",
            icon: "building.columns",
            minimumLevel: 5,
            isMandatoryByDefault: true
        ),
        .machineLearning: WordStackMetadata(
            displayName: "Machine Learning",
            description: "Model terminology, training, inference, and embeddings",
            icon: "brain",
            minimumLevel: 5,
            isMandatoryByDefault: false
        ),
        .securityArchitecture: WordStackMetadata(
            displayName: "Security Architecture",
            description: "Security architecture, compliance, and zero-trust design",
            icon: "lock.rectangle.stack",
            minimumLevel: 5,
            isMandatoryByDefault: false
        ),
        .dataPlatform: WordStackMetadata(
            displayName: "Data Platform",
            description: "Data platform architecture, governance, and analytics",
            icon: "chart.bar.doc.horizontal",
            minimumLevel: 5,
            isMandatoryByDefault: false
        )
    ]

    private var info: WordStackMetadata {
        Self.metadata[self]!
    }

    var displayName: String { info.displayName }
    var description: String { info.description }
    var icon: String { info.icon }
    var minimumLevel: Int { info.minimumLevel }
    var isMandatoryByDefault: Bool { info.isMandatoryByDefault }

    static func mandatoryStacks(for level: Int) -> Set<WordStack> {
        Set(allCases.filter { $0.isMandatoryByDefault && $0.minimumLevel <= level })
    }

    static func newMandatoryStacks(for level: Int) -> Set<WordStack> {
        Set(allCases.filter { $0.isMandatoryByDefault && $0.minimumLevel == level })
    }

    static func availableOptionalStacks(for level: Int) -> Set<WordStack> {
        Set(allCases.filter { !$0.isMandatoryByDefault && $0.minimumLevel <= level })
    }

    static func newOptionalStacks(for level: Int) -> Set<WordStack> {
        Set(allCases.filter { !$0.isMandatoryByDefault && $0.minimumLevel == level })
    }
}

// MARK: - Metadata

struct WordStackMetadata {
    let displayName: String
    let description: String
    let icon: String
    let minimumLevel: Int
    let isMandatoryByDefault: Bool
}
