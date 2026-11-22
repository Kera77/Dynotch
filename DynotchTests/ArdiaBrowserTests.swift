@testable import Dynotch
import Testing

/// Spec E-2e: Ardia counts as a browser like Zen; its alert helper is Ardia itself.
struct ArdiaBrowserTests {
    @Test func ardiaIsSharedBrowser() {
        #expect(WebNotificationSource.isShared("com.ardia.browser"))
        #expect(WebNotificationSource.isShared("app.zen-browser.zen"))
    }

    @Test func alertHelperIsTheBrowser() {
        let helper = "com.ardia.browser.framework.AlertNotificationService"
        #expect(WebNotificationSource.owningApp(helper) == "com.ardia.browser")
        #expect(WebNotificationSource.isShared(WebNotificationSource.owningApp(helper)))
        #expect(WebNotificationSource.owningApp("com.tinyspeck.slackmacgap") == "com.tinyspeck.slackmacgap")
    }

    @Test func ardiaWebAppIsWebApp() {
        #expect(WebNotificationSource.isWebApp("com.ardia.browser.app.abcdef"))
        #expect(!WebNotificationSource.isWebApp("com.ardia.browser"))
    }

    /// Spec E-2f: which apps count when picking the browser in use.
    @Test func browserDetection() {
        #expect(ActiveBrowser.isBrowser(bundleID: "com.ardia.browser"))
        #expect(ActiveBrowser.isBrowser(bundleID: "app.zen-browser.zen"))
        #expect(!ActiveBrowser.isBrowser(bundleID: "com.ardia.browser.app.abcdef"))
        #expect(!ActiveBrowser.isBrowser(bundleID: "com.apple.Safari.WebApp.2C5A3228"))
        #expect(!ActiveBrowser.isBrowser(bundleID: "com.tinyspeck.slackmacgap"))
    }
}
