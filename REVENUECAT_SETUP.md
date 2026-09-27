# Home Passport RevenueCat setup

The app-side purchase flow is complete, but purchases remain disabled until the identifiers below are configured.

## App Store Connect and RevenueCat

1. Create one **Non-Consumable** in-app purchase in App Store Connect for the lifetime Pro unlock.
2. Create or select the Home Passport app in RevenueCat and connect the App Store credentials.
3. Import the non-consumable product into RevenueCat.
4. Create the entitlement `home_passport_pro` and attach the product.
5. Add the product to RevenueCat's **Current Offering**. A custom offering identifier is optional.
6. In RevenueCat **Project settings → General → Restore behavior**, select **Transfer to new App User ID**.
7. Add the RevenueCat public Apple SDK key to `PurchaseConfiguration.revenueCatAPIKey`.
8. Add the exact App Store Connect product ID to `PurchaseConfiguration.proProductIdentifiers`.
9. Add the published privacy-policy URL to `PurchaseConfiguration.privacyPolicyURL` before release.

The purchase flow stays disabled until both the public SDK key and at least one Pro product identifier are present. This prevents shipping a checkout that can sell Pro but cannot recognize that product through StoreKit after reinstall.

Do not store a separate Pro flag in `UserDefaults`. RevenueCat `CustomerInfo` and verified StoreKit 2 current entitlements are the source of truth.

## Reinstall behavior

Home Passport stores a random custom RevenueCat App User ID in Keychain. A normal reinstall on the same device generally retains that identifier, allowing RevenueCat to load the same customer.

Separately, `Transaction.currentEntitlements` silently reads verified current transactions for the configured product ID. This does not call `restorePurchases()`, `syncPurchases()`, or `AppStore.sync()`, and does not intentionally show an Apple Account prompt. **Restore Purchase** remains a user-initiated fallback.

## Sandbox verification

1. Install a sandbox or TestFlight build and buy the lifetime unlock.
2. Confirm Pro becomes active immediately.
3. Record the RevenueCat App User ID shown for the customer.
4. Delete and reinstall the app on the same device.
5. Confirm Pro activates automatically without tapping Restore and that the RevenueCat customer uses the same App User ID.
6. Install on another device using the same sandbox Apple Account and confirm StoreKit's verified current entitlement unlocks Pro without Restore.
7. Test **Restore Purchase** separately and confirm RevenueCat's configured transfer behavior.
8. Test Restore with an Apple Account that has no purchase and confirm access remains locked.

## Free and Pro limits

- Free: up to 5 saved items and 1 home.
- Pro: unlimited saved items and multiple homes.
- Editing, deleting, reminders, shopping mode, and local backup remain available for existing data.
