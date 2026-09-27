import Combine
import Foundation
import RevenueCat
import StoreKit

enum PurchaseAvailability: Equatable {
    case notConfigured
    case loading
    case ready
    case unavailable(String)
}

enum PurchaseFeedback: Equatable, Identifiable {
    case restored
    case noPurchasesFound
    case failed(String)

    var id: String {
        switch self {
        case .restored: "restored"
        case .noPurchasesFound: "no-purchases"
        case .failed(let message): "failed-\(message)"
        }
    }

    var title: String {
        switch self {
        case .restored: "Purchase restored"
        case .noPurchasesFound: "No purchase found"
        case .failed: "Something went wrong"
        }
    }

    var message: String {
        switch self {
        case .restored: "Home Passport Pro is active on this device."
        case .noPurchasesFound: "We couldn't find an active Home Passport Pro purchase for this Apple Account."
        case .failed(let message): message
        }
    }
}

struct PurchaseOption: Equatable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let localizedPrice: String
}

@MainActor
final class PurchaseManager: NSObject, ObservableObject {
    @Published private(set) var isPro = false
    @Published private(set) var options: [PurchaseOption] = []
    @Published private(set) var availability: PurchaseAvailability = .notConfigured
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var feedback: PurchaseFeedback?

    private var didConfigure = false
    private var revenueCatIsPro = false
    private var storeKitIsPro = false
    private var packagesByID: [String: Package] = [:]
    private var accessRefreshTask: Task<Void, Never>?

    override init() { super.init() }

    func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        guard PurchaseConfiguration.isReady else {
            availability = .notConfigured
            Task { await refreshAccessState() }
            return
        }

#if DEBUG
        Purchases.logLevel = .debug
#else
        Purchases.logLevel = .error
#endif

        let appUserID: String
        do {
            appUserID = try RevenueCatIdentityStore.appUserID()
        } catch {
            didConfigure = false
            availability = .unavailable("Purchases aren't available on this device right now.")
            return
        }

        Purchases.configure(
            withAPIKey: PurchaseConfiguration.revenueCatAPIKey,
            appUserID: appUserID
        )
        Purchases.shared.delegate = self

        Task { await refreshAccessState() }
    }

    func preparePaywall() async {
        configureIfNeeded()
        guard didConfigure, PurchaseConfiguration.isReady else {
            await refreshAccessState()
            return
        }
        await refreshAccessState()
        if options.isEmpty { await loadOfferings() }
    }

    func ensureAccessResolved() async {
        configureIfNeeded()
        await refreshAccessState()
    }

    func applicationDidBecomeActive() async {
        await refreshStoreKitEntitlements()
    }

    private func refreshAccessState() async {
        if let accessRefreshTask {
            await accessRefreshTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            async let storeKitRefresh: Void = refreshStoreKitEntitlements()
            async let revenueCatRefresh: Void = refreshCustomerInfo()
            _ = await (storeKitRefresh, revenueCatRefresh)
        }
        accessRefreshTask = task
        await task.value
        accessRefreshTask = nil
    }

    /// This reads locally available, verified StoreKit transactions. It does not call
    /// AppStore.sync(), syncPurchases(), or the interactive restore flow.
    func refreshStoreKitEntitlements() async {
        guard !PurchaseConfiguration.proProductIdentifiers.isEmpty else { return }
        var hasActiveProTransaction = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if PurchaseConfiguration.proProductIdentifiers.contains(transaction.productID) {
                hasActiveProTransaction = true
                break
            }
        }
        storeKitIsPro = hasActiveProTransaction
        updateProStatus()
    }

    func refreshCustomerInfo() async {
        guard didConfigure, PurchaseConfiguration.isReady else { return }
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            // Keep the last verified access state through a transient offline failure.
        }
    }

    func loadOfferings() async {
        guard didConfigure, PurchaseConfiguration.isReady else {
            availability = .notConfigured
            return
        }
        availability = .loading
        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = PurchaseConfiguration.preferredOfferingIdentifier
                .flatMap { offerings.offering(identifier: $0) } ?? offerings.current
            let packages = (offering?.availablePackages ?? []).filter {
                PurchaseConfiguration.proProductIdentifiers.contains(
                    $0.storeProduct.productIdentifier
                )
            }
            packagesByID = Dictionary(uniqueKeysWithValues: packages.map { ($0.identifier, $0) })
            options = packages.map {
                PurchaseOption(
                    id: $0.identifier,
                    title: $0.storeProduct.localizedTitle,
                    detail: $0.storeProduct.localizedDescription,
                    localizedPrice: $0.storeProduct.localizedPriceString
                )
            }
            availability = options.isEmpty
                ? .unavailable("No product is attached to the current RevenueCat offering yet.")
                : .ready
        } catch {
            availability = .unavailable("The unlock couldn't be loaded. Check your connection and try again.")
        }
    }

    @discardableResult
    func purchase(optionID: String) async -> Bool {
        guard let package = packagesByID[optionID],
              !isPurchasing, didConfigure, PurchaseConfiguration.isReady else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(result.customerInfo)
            return isPro
        } catch let error as RevenueCat.ErrorCode where error == .purchaseCancelledError {
            return false
        } catch {
            feedback = .failed("Your purchase wasn't completed. Please try again.")
            return false
        }
    }

    func restorePurchases() async {
        guard !isRestoring, didConfigure, PurchaseConfiguration.isReady else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            apply(try await Purchases.shared.restorePurchases())
            feedback = isPro ? .restored : .noPurchasesFound
        } catch {
            feedback = .failed("We couldn't restore your purchase. Check your connection and try again.")
        }
    }

    private func apply(_ customerInfo: CustomerInfo) {
        revenueCatIsPro = customerInfo.entitlements[
            PurchaseConfiguration.entitlementIdentifier
        ]?.isActive == true
        updateProStatus()
    }

    private func updateProStatus() {
        let newValue = revenueCatIsPro || storeKitIsPro
        guard newValue != isPro else { return }
        isPro = newValue
    }
}

extension PurchaseManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in apply(customerInfo) }
    }
}
