import OSLog

extension Logger {
    /// App-wide logging subsystem. Used everywhere we instantiate a `Logger`.
    static let subsystem = "com.stackspeak.ios"

    /// Shorthand for `Logger(subsystem: Logger.subsystem, category: category)`.
    init(category: String) {
        self.init(subsystem: Logger.subsystem, category: category)
    }
}
