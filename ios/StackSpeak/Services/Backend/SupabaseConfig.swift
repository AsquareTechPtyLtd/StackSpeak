import Foundation

/// Supabase connection values. The anon (publishable) key + project URL are
/// safe to ship in the client *only because* Row Level Security restricts each
/// user to their own row — but they still load from a **git-ignored** file
/// (`Supabase.plist`) so keys aren't committed. The service_role key and DB
/// password never live in the app. See CLAUDE.md → "Backend & Sync".
struct SupabaseConfig: Equatable {
    let url: URL
    let anonKey: String

    /// Loads from `Supabase.plist` in the main bundle. Returns nil when the file
    /// is absent or contains the placeholder values — in which case the app runs
    /// local-only (`NoOpBackendService`).
    static func loadFromBundle(_ bundle: Bundle = .main) -> SupabaseConfig? {
        guard let plistURL = bundle.url(forResource: "Supabase", withExtension: "plist"),
              let data = try? Data(contentsOf: plistURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        guard let urlString = (dict["SUPABASE_URL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let anonKey = (dict["SUPABASE_ANON_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty, !anonKey.isEmpty,
              !urlString.contains("YOUR_"), !anonKey.contains("YOUR_"),   // reject the template
              let url = URL(string: urlString)
        else { return nil }

        return SupabaseConfig(url: url, anonKey: anonKey)
    }
}
