import SwiftUI

enum PaywallReason {
    case settings
    case itemLimit
    case homeLimit

    var subtitle: String {
        switch self {
        case .settings: "Keep every home detail ready when you need it."
        case .itemLimit: "Your free collection is full. Unlock unlimited saved items."
        case .homeLimit: "Keep a separate list for every home you care for."
        }
    }
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var purchaseManager: PurchaseManager

    let reason: PaywallReason

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image("ProPassportHero")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 360)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ONE-TIME PURCHASE")
                            .font(.caption2.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(PassportTheme.teal)
                        Text("HomeParts Pro")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(PassportTheme.ink)
                        Text(reason.subtitle)
                            .font(.body)
                            .foregroundStyle(PassportTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    PassportCard {
                        VStack(spacing: 0) {
                            benefit(
                                "Unlimited saved items",
                                "Keep every filter, bulb, battery, and appliance part."
                            )
                            Divider().padding(.leading, 40)
                            benefit(
                                "Multiple homes",
                                "Organize your home, rental, cabin, or a family property."
                            )
                            Divider().padding(.leading, 40)
                            benefit(
                                "Permanent Pro access",
                                "Buy once and use Pro without a recurring subscription."
                            )
                        }
                    }

                    productCard
                    restoreAndLegal
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 116)
                .passportContentWidth(560)
            }
            .background(PassportTheme.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PassportTheme.ink)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.92), in: Circle())
                            .overlay(Circle().stroke(PassportTheme.line, lineWidth: 1))
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                purchaseFooter
            }
            .task {
                await purchaseManager.preparePaywall()
                if purchaseManager.isPro { dismiss() }
            }
            .onChange(of: purchaseManager.isPro) { isPro in
                if isPro { dismiss() }
            }
            .alert(item: $purchaseManager.feedback) { feedback in
                Alert(
                    title: Text(feedback.title),
                    message: Text(feedback.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func benefit(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(PassportTheme.teal)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PassportTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(PassportTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private var productCard: some View {
        switch purchaseManager.availability {
        case .notConfigured:
            PassportCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lifetime Unlock")
                        .font(.headline)
                        .foregroundStyle(PassportTheme.ink)
                    Text("Purchases are not available yet.")
                        .font(.subheadline)
                        .foregroundStyle(PassportTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .loading:
            PassportCard {
                HStack(spacing: 12) {
                    ProgressView().tint(PassportTheme.teal)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Lifetime Unlock")
                            .font(.headline)
                            .foregroundStyle(PassportTheme.ink)
                        Text("Loading App Store price…")
                            .font(.caption)
                            .foregroundStyle(PassportTheme.muted)
                    }
                }
            }
        case .unavailable(let message):
            PassportCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("The unlock is unavailable")
                        .font(.headline)
                        .foregroundStyle(PassportTheme.ink)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(PassportTheme.muted)
                    Button("Try again") { Task { await purchaseManager.loadOfferings() } }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PassportTheme.teal)
                }
            }
        case .ready:
            if let option = purchaseManager.options.first {
                lifetimeCard(option)
            }
        }
    }

    private func lifetimeCard(_ option: PurchaseOption) -> some View {
        PassportCard {
            HStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(PassportTheme.teal)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lifetime Unlock")
                        .font(.headline)
                        .foregroundStyle(PassportTheme.ink)
                    Text("One-time purchase · No subscription")
                        .font(.caption)
                        .foregroundStyle(PassportTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(option.localizedPrice)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PassportTheme.ink)
                    .multilineTextAlignment(.trailing)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Lifetime Unlock, \(option.localizedPrice), one-time purchase, no subscription"
        )
    }

    private var selectedOption: PurchaseOption? {
        purchaseManager.options.first
    }

    private var purchaseFooter: some View {
        VStack(spacing: 8) {
            Button {
                guard let selectedOption else { return }
                Task {
                    if await purchaseManager.purchase(optionID: selectedOption.id) {
                        dismiss()
                    }
                }
            } label: {
                Group {
                    if purchaseManager.isPurchasing {
                        HStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text("Purchasing…")
                        }
                    } else if purchaseManager.isPro {
                        Text("Pro is active")
                    } else if let selectedOption {
                        Text("Unlock Pro · \(selectedOption.localizedPrice)")
                    } else {
                        Text("Unlock Pro")
                    }
                }
            }
            .buttonStyle(PassportPrimaryButton())
            .disabled(selectedOption == nil || purchaseManager.isPurchasing || purchaseManager.isPro)
            .opacity(selectedOption == nil || purchaseManager.isPro ? 0.55 : 1)

            Text("One payment. Permanent access. No recurring charge.")
                .font(.caption2)
                .foregroundStyle(PassportTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { PassportTheme.line.frame(height: 1) }
    }

    private var restoreAndLegal: some View {
        VStack(spacing: 13) {
            Button {
                Task { await purchaseManager.restorePurchases() }
            } label: {
                if purchaseManager.isRestoring {
                    ProgressView().tint(PassportTheme.teal)
                } else {
                    Text("Restore Purchase")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PassportTheme.teal)
            .disabled(purchaseManager.isRestoring || !PurchaseConfiguration.isReady)

            Text("Payment is charged to your Apple Account after confirmation. You can restore this purchase on devices using the same Apple Account.")
                .font(.caption2).foregroundStyle(PassportTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 20) {
                Button("Terms of Use") { openURL(PurchaseConfiguration.termsOfUseURL) }
                if let privacyURL = PurchaseConfiguration.privacyPolicyURL {
                    Button("Privacy Policy") { openURL(privacyURL) }
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(PassportTheme.teal)
        }
    }
}
