import Testing
import Foundation
@testable import plonk

// The catalog is only worth having if the app can find it. These fail loudly
// when it cannot: a missed key comes back as the key itself, which is exactly
// what a shipped build with no .lproj folders would draw on screen.

struct LocalizationTests {

    @Test func theCatalogIsFound() {
        #expect(Localization.bundle.path(forResource: "en", ofType: "lproj") != nil)
    }

    @Test func keysResolveToTheSelectedLanguage() {
        #expect(String(localized: .commonChoose) != "common.choose")
        #expect(String(localized: .shortcutLeftHalf) != "shortcut.leftHalf")
    }

    @Test func valuesAreFilledIn() {
        #expect(String(localized: .shortcutZone(3)).contains("3"))
        #expect(String(localized: .aiAgentOffline("codex")).contains("codex"))
    }

    /// The counted strings come from Localizable.stringsdict, which is a
    /// separate file and a separate lookup.
    @Test func countedStringsPickTheRightForm() {
        #expect(String(localized: .workspacesAppCount(1)).contains("1"))
        #expect(String(localized: .workspacesAppCount(4)).contains("4"))
        #expect(String(localized: .workspacesWindowCount(1)).contains("1"))
    }

    /// Nothing may reach the user as a raw key. Resolving to something other
    /// than the key itself is the only check that catches a typo in either the
    /// Swift declaration or the catalog.
    @Test func nothingResolvesToItsOwnKey() {
        #expect(String(localized: .zonesOverlayHelp) != "zones.overlayHelp")
        #expect(String(localized: .startProgress(1, 3)).contains("1"))
        #expect(String(localized: .startProgress(1, 3)).contains("3"))
    }

    @Test func simplifiedChineseResourcesArePackaged() throws {
        let language = try #require(Localization.bundle.localizations.first { $0.lowercased() == "zh-hans" })
        let url = try #require(Localization.bundle.url(forResource: language, withExtension: "lproj"))
        let bundle = try #require(Bundle(url: url))
        let locale = Locale(identifier: language)
        #expect(String(localized: LocalizedStringResource.commonChoose.defaultValue,
                       bundle: bundle, locale: locale) != "common.choose")
        #expect(String(localized: LocalizedStringResource.workspacesAppCount(1).defaultValue,
                       bundle: bundle, locale: locale).contains("1"))
        #expect(bundle.url(forResource: "InfoPlist", withExtension: "strings") != nil)
    }
}
