import Foundation
import Testing

/// The app's own code reads UserDefaults (its preferences and the App Group), a
/// required-reason API: the manifest must ship in the bundle with both reasons.
struct PrivacyManifestTests {
    @Test("la app trae su propio privacy manifest con las razones de UserDefaults")
    func appBundlesPrivacyManifest() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        let apis = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaults = try #require(apis.first {
            $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        })
        let reasons = userDefaults["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
        #expect(Set(reasons) == ["CA92.1", "1C8F.1"])
    }
}
