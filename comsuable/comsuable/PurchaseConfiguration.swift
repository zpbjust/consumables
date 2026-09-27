import Foundation

enum PurchaseConfiguration {
    /// Add the public Apple SDK key after the HomeParts RevenueCat project is created.
    static let revenueCatAPIKey = "appl_fheedUWfBEzoySoqNFYttEPBfVv"

    /// Create this entitlement in RevenueCat and attach the lifetime product to it.
    static let entitlementIdentifier = "home_replacements_pro"

    /// This identifier is permanent after the product is created in App Store Connect.
    static let lifetimeProductIdentifier = "com.fuyao.comsuable.pro.lifetime"
    static let proProductIdentifiers: Set<String> = [lifetimeProductIdentifier]

    /// RevenueCat offering containing the `$rc_lifetime` package.
    static let preferredOfferingIdentifier: String? = "default"

    static let termsOfUseURL = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!

    static let privacyPolicyURL: URL? = URL(
        string: "https://doudousoftware.com/homeparts/privacy/"
    )

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
