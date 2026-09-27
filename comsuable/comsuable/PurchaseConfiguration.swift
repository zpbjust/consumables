import Foundation

enum PurchaseConfiguration {
    /// Add the public Apple SDK key after the Home Passport RevenueCat project is created.
    static let revenueCatAPIKey = ""

    /// Create this entitlement in RevenueCat and attach the lifetime product to it.
    static let entitlementIdentifier = "home_passport_pro"

    /// Add the exact App Store Connect lifetime product identifier before release.
    static let proProductIdentifiers: Set<String> = []

    /// Uses RevenueCat's current offering unless a dedicated offering is configured later.
    static let preferredOfferingIdentifier: String? = nil

    static let termsOfUseURL = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!

    /// Set this to the published Home Passport privacy policy before enabling purchases.
    static let privacyPolicyURL: URL? = nil

    static var isReady: Bool {
        let hasValidSDKKey = revenueCatAPIKey.hasPrefix("appl_") || revenueCatAPIKey.hasPrefix("test_")
        return hasValidSDKKey && !proProductIdentifiers.isEmpty
    }
}

enum PremiumAccessPolicy {
    static let freeItemLimit = 5
    static let freeHomeLimit = 1

    static func canCreateItem(
        existingItemCount: Int,
        isPro: Bool,
        purchasesConfigured: Bool = PurchaseConfiguration.isReady
    ) -> Bool {
        !purchasesConfigured || isPro || existingItemCount < freeItemLimit
    }

    static func canCreateHome(
        existingHomeCount: Int,
        isPro: Bool,
        purchasesConfigured: Bool = PurchaseConfiguration.isReady
    ) -> Bool {
        !purchasesConfigured || isPro || existingHomeCount < freeHomeLimit
    }
}
