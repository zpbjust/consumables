import SwiftUI

enum PaywallReason {
    case settings
    case itemLimit
    case homeLimit

    var subtitle: String {
        switch self {
        case .settings: "Keep every home detail ready when you need it."
        case .itemLimit: "You've filled your free passport. Unlock unlimited items."
        case .homeLimit: "Keep a separate passport for every place you care for."
        }
    }
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var purchaseManager: PurchaseManager

    let reason: PaywallReason
    @State private var selectedOptionID: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image("ProPassportHero")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Home Passport Pro")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(PassportTheme.ink)
                        Text(reason.subtitle)
                            .foregroundStyle(PassportTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    PassportCard {
                        VStack(spacing: 0) {
                            benefit("Unlimited saved items", "Keep every filter, bulb, battery, and appliance part.")
                            Divider().padding(.leading, 24)
                            benefit("Multiple homes", "Organize a primary home, rental, cabin, or family property.")
                            Divider().padding(.leading, 24)
                            benefit("One-time unlock", "Pay once and keep Pro—there is no recurring subscription.")
                        }
                    }

                    plans
                    purchaseButton
                    restoreAndLegal
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .passportContentWidth(680)
            }
            .background(PassportTheme.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade")
                            .font(.headline)
                            .foregroundStyle(PassportTheme.ink)
                        Text(purchaseManager.isPro ? "Pro is active" : "Lifetime access")
                            .font(.caption)
                            .foregroundStyle(PassportTheme.muted)
                    }
                    Spacer()
                    Button("Close") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PassportTheme.teal)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .overlay(alignment: .bottom) { PassportTheme.line.frame(height: 1) }
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
            RoundedRectangle(cornerRadius: 3)
                .fill(PassportTheme.teal)
                .frame(width: 5, height: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(PassportTheme.ink)
                Text(detail).font(.caption).foregroundStyle(PassportTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var plans: some View {
        switch purchaseManager.availability {
        case .notConfigured:
            PassportCard {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Pro is almost ready").font(.headline).foregroundStyle(PassportTheme.ink)
                    Text("The one-time unlock will appear here after the App Store and RevenueCat product is connected.")
                        .font(.subheadline).foregroundStyle(PassportTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .loading:
            PassportCard {
                HStack(spacing: 12) {
                    ProgressView().tint(PassportTheme.teal)
                    Text("Loading the unlock…").foregroundStyle(PassportTheme.muted)
                }
            }
        case .unavailable(let message):
            PassportCard {
                VStack(alignment: .leading, spacing: 9) {
                    Text("The unlock is unavailable").font(.headline).foregroundStyle(PassportTheme.ink)
                    Text(message).font(.subheadline).foregroundStyle(PassportTheme.muted)
                    Button("Try again") { Task { await purchaseManager.loadOfferings() } }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(PassportTheme.teal)
                }
            }
        case .ready:
            VStack(spacing: 10) {
                ForEach(purchaseManager.options) { option in
                    optionCard(option)
                }
            }
        }
    }

    private func optionCard(_ option: PurchaseOption) -> some View {
        let selected = option.id == selectedOption?.id
        return Button {
            selectedOptionID = option.id
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .stroke(selected ? PassportTheme.teal : PassportTheme.line, lineWidth: 2)
                    .background {
                        if selected { Circle().fill(PassportTheme.teal).padding(5) }
                    }
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.headline).foregroundStyle(PassportTheme.ink)
                    Text(option.detail)
                        .font(.caption).foregroundStyle(PassportTheme.muted).lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(option.localizedPrice)
                    .font(.headline).foregroundStyle(PassportTheme.ink)
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(selected ? PassportTheme.teal : PassportTheme.line, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.title), \(option.localizedPrice)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var selectedOption: PurchaseOption? {
        purchaseManager.options.first { $0.id == selectedOptionID } ?? purchaseManager.options.first
    }

    private var purchaseButton: some View {
        Button {
            guard let selectedOption else { return }
            Task {
                if await purchaseManager.purchase(optionID: selectedOption.id) { dismiss() }
            }
        } label: {
            Group {
                if purchaseManager.isPurchasing {
                    ProgressView().tint(.white)
                } else if purchaseManager.isPro {
                    Text("Pro is active")
                } else if let selectedOption {
                    Text("Unlock forever · \(selectedOption.localizedPrice)")
                } else {
                    Text("Unlock Home Passport Pro")
                }
            }
        }
        .buttonStyle(PassportPrimaryButton())
        .disabled(selectedOption == nil || purchaseManager.isPurchasing || purchaseManager.isPro)
        .opacity(selectedOption == nil || purchaseManager.isPro ? 0.55 : 1)
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

            Text("One-time purchase. Payment is charged to your Apple Account after confirmation. You can restore it on devices using the same Apple Account.")
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
