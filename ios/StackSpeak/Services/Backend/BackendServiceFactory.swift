import Foundation

/// Single construction point for the app's `BackendService`. Returns the live
/// Supabase conformer when a config is present, else a `NoOpBackendService` so
/// the app runs fully local. Callers depend only on the `BackendService`
/// protocol and never learn which one they got.
enum BackendServiceFactory {
    static func make(config: SupabaseConfig? = SupabaseConfig.loadFromBundle()) -> BackendService {
        guard let config else { return NoOpBackendService() }
        return SupabaseBackendService(config: config)
    }
}
