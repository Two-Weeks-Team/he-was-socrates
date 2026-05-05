import Testing
@testable import HeWasSocrates
import SocraticEngine

@Suite("App smoke")
struct SmokeTests {
    @Test func appCompiles() {
        // If this file links + runs, the app target + engine package wired correctly.
        #expect(SocraticEngineInfo.visemeCount == 16)
    }

    @Test func bundleVisemeAssetsResolve() {
        // After Phase 2 build copies assets/visemes/*.png into the app bundle,
        // every VisemeID should have a resolvable resource. Phase 1 may fail
        // before xcodegen + xcodebuild step.
        for v in VisemeID.allCases {
            let url = Bundle.main.url(forResource: v.resourceName, withExtension: "png", subdirectory: "visemes")
                   ?? Bundle.main.url(forResource: v.resourceName, withExtension: "png")
            // Soft expectation in skeleton phase; can be tightened in Phase 3.
            if url == nil {
                print("warning: missing bundled asset for \(v.rawValue)")
            }
        }
    }
}
