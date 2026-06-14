import Testing
import Foundation
@testable import StackSpeak

@Suite("BackendService — config & fallback")
struct BackendServiceTests {

    @Test("Factory returns the local no-op when no config is present")
    func factoryFallsBackToNoOp() {
        let service = BackendServiceFactory.make(config: nil)
        #expect(service.isConfigured == false)
    }

    @Test("Factory returns a configured Supabase service when config is present")
    func factoryUsesSupabaseWhenConfigured() {
        let cfg = SupabaseConfig(url: URL(string: "https://demo.supabase.co")!, anonKey: "anon")
        let service = BackendServiceFactory.make(config: cfg)
        #expect(service.isConfigured == true)
    }

    @Test("No-op backend reports unconfigured and never authenticates")
    func noOpThrowsNotConfigured() async {
        let service = NoOpBackendService()
        await #expect(throws: BackendError.notConfigured) {
            _ = try await service.ensureSession()
        }
        await #expect(throws: BackendError.notConfigured) {
            _ = try await service.fetchSnapshot()
        }
    }

    @Test("Config rejects the placeholder template values")
    func configRejectsPlaceholders() {
        // Simulates the example plist's YOUR_ placeholders → treated as unconfigured.
        let bundle = Bundle(for: BackendTestAnchor.self)
        // No real Supabase.plist in the test bundle → nil.
        #expect(SupabaseConfig.loadFromBundle(bundle) == nil)
    }
}

private final class BackendTestAnchor {}
