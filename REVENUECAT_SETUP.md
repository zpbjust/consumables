# HomeParts in-app purchase setup

The app-side RevenueCat and StoreKit 2 integration is complete, and the RevenueCat public Apple SDK key is configured in `PurchaseConfiguration.swift`.

## Fixed identifiers

- App name: `HomeParts`
- Bundle ID: `com.fuyao.comsuable`
- Product type: Non-Consumable
- Product ID: `com.fuyao.comsuable.pro.lifetime`
- RevenueCat entitlement lookup key: `home_replacements_pro` (keep this exact key; it is already wired in the app)
- RevenueCat offering identifier: `default`
- RevenueCat package identifier: `$rc_lifetime`
- United States price: `$6.99`

Do not change the product ID after creating it in App Store Connect. The product ID follows the existing Bundle ID, which remains unchanged after the product rename.

## App Store Connect

### Agreements and app capability

1. Accept the Paid Apps Agreement.
2. Complete tax and banking details.
3. Confirm the app record uses Bundle ID `com.fuyao.comsuable`.
4. Confirm the Xcode target has the **In-App Purchase** capability.

### Create the product

Open **App Store Connect → HomeParts → Monetization → In-App Purchases** and create:

- Type: `Non-Consumable`
- Reference Name: `HomeParts Pro Lifetime`
- Product ID: `com.fuyao.comsuable.pro.lifetime`
- Price: United States `USD 6.99`
- Family Sharing: leave disabled for the first release
- Cleared for Sale: enabled

Add English (U.S.) localization:

- Display Name: `HomeParts Pro Lifetime`
- Description: `Unlimited items and homes, unlocked forever.`

Upload an App Review screenshot showing the paywall with the lifetime product. The first in-app purchase must be submitted for review with the app version that contains the purchase flow.

### App metadata

Before submission:

1. Set the App Store name to `HomeParts`.
2. Add the published privacy-policy URL to App Store Connect.
3. Keep Apple's Standard EULA unless a custom license is required.
4. Do not place a fixed dollar price in screenshots or store description; localized pricing comes from the App Store.

### App Review notes

```text
HomeParts does not require an account or sign-in.

To review the in-app purchase:
1. Open the Settings tab.
2. Tap the HomeParts Pro membership card.
3. The paywall displays the Lifetime product using its localized App Store price.

The free version supports up to 5 saved items and 1 home.
HomeParts Pro unlocks unlimited saved items and multiple homes.

The Lifetime product is a non-consumable one-time purchase and does not renew.
The paywall contains Restore Purchase, Privacy Policy, and Terms of Use links.
No external payment method is offered.
```

## RevenueCat

1. Create a project named `HomeParts`.
2. Add an iOS app with Bundle ID `com.fuyao.comsuable`.
3. Connect the App Store Connect credentials requested by RevenueCat.
4. Import `com.fuyao.comsuable.pro.lifetime`.
5. Create entitlement `home_replacements_pro`.
6. Attach the lifetime product to that entitlement.
7. Create offering `default` and mark it as the Current Offering.
8. Add package `$rc_lifetime` to `default`.
9. Attach the lifetime product to `$rc_lifetime`.
10. In **Project settings → General → Restore behavior**, select **Transfer to new App User ID**.

Confirm the **public Apple SDK key** beginning with `appl_` remains configured in:

```swift
static let revenueCatAPIKey = "appl_..."
```

Do not add a RevenueCat secret key to the app.

After publishing the privacy policy, also set:

```swift
static let privacyPolicyURL: URL? = URL(
    string: "https://your-domain.example/home-replacements/privacy/"
)
```

With a valid SDK key and product ID present, the free limits are active. Finish the App Store Connect product, entitlement, offering, and package setup before distributing this build.

## Entitlement behavior

Do not store a separate Pro flag in `UserDefaults`. RevenueCat `CustomerInfo` and verified StoreKit 2 `Transaction.currentEntitlements` are the sources of truth.

HomeParts stores a random custom RevenueCat App User ID in Keychain. A normal reinstall on the same device generally retains that identifier. StoreKit 2 independently checks verified transactions for the exact lifetime product ID, including on another device using the same Apple Account.

**Restore Purchase** remains a user-initiated fallback.

## Sandbox and TestFlight verification

1. Confirm the paywall loads the localized `$6.99` sandbox price.
2. Buy the lifetime product and confirm Pro activates immediately.
3. Confirm saving a sixth item succeeds after purchase.
4. Confirm creating a second home succeeds after purchase.
5. Cancel a purchase and confirm no error alert appears.
6. Delete and reinstall the app on the same device; confirm Pro activates without Restore.
7. Install on another device using the same sandbox Apple Account; confirm the StoreKit entitlement unlocks Pro.
8. Test **Restore Purchase** with an account that owns the product.
9. Test Restore with an account that has no purchase; confirm access remains locked.
10. Test the unavailable state with the network disconnected.

## Free and Pro limits

- Free: up to 5 saved items and 1 home.
- Pro: unlimited saved items and multiple homes.
- Editing, deleting, reminders, shopping mode, CSV export, and local backup remain available for existing data.
