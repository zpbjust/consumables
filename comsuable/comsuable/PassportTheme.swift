import SwiftUI
import UIKit

enum PassportTheme {
    static let canvas = Color(red: 0.975, green: 0.982, blue: 0.971)
    static let ink = Color(red: 0.09, green: 0.17, blue: 0.20)
    static let muted = Color(red: 0.40, green: 0.48, blue: 0.49)
    static let teal = Color(red: 0.04, green: 0.43, blue: 0.40)
    static let pale = Color(red: 0.88, green: 0.95, blue: 0.91)
    static let amber = Color(red: 0.88, green: 0.56, blue: 0.24)
    static let line = Color(red: 0.86, green: 0.90, blue: 0.87)
    static let shadow = Color.black.opacity(0.055)
}

struct PassportCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(PassportTheme.line, lineWidth: 1))
            .shadow(color: PassportTheme.shadow, radius: 12, y: 5)
    }
}

struct PassportSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PassportTheme.line, lineWidth: 1)
            }
            .shadow(color: PassportTheme.shadow, radius: 10, y: 4)
    }
}

enum PassportPageTitleCoordinateSpace {
    static let name = "passport.page.scroll"
}

struct PassportPageTitleBottomKey: PreferenceKey {
    static var defaultValue = CGFloat.greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

enum PassportPinnedTitleVisibility {
    static func next(current: Bool, titleBottom: CGFloat) -> Bool {
        guard titleBottom.isFinite, abs(titleBottom) < 10_000 else { return current }
        if current {
            return titleBottom < 0
        }
        return titleBottom <= -8
    }
}

struct PassportPageTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(PassportTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: PassportPageTitleBottomKey.self,
                        value: proxy.frame(in: .named(PassportPageTitleCoordinateSpace.name)).maxY
                    )
                }
            }
            .accessibilityAddTraits(.isHeader)
    }
}

private struct PassportCollapsingTitleModifier: ViewModifier {
    let title: String
    @State private var showsCompactTitle = false

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: PassportPageTitleCoordinateSpace.name)
            .overlay(alignment: .top) {
                if showsCompactTitle {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(PassportTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(PassportTheme.canvas.opacity(0.98))
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(PassportTheme.line)
                                .frame(height: 0.5)
                        }
                        .allowsHitTesting(false)
                        .accessibilityAddTraits(.isHeader)
                        .transition(.opacity)
                }
            }
            .onPreferenceChange(PassportPageTitleBottomKey.self) { titleBottom in
                let shouldShow = titleBottom <= 0
                guard shouldShow != showsCompactTitle else { return }
                withAnimation(.easeOut(duration: 0.14)) {
                    showsCompactTitle = shouldShow
                }
            }
            .toolbar(.hidden, for: .navigationBar)
    }
}

struct PassportFloatingButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(height: 52)
                .background(PassportTheme.teal, in: Capsule())
                .shadow(color: PassportTheme.teal.opacity(0.25), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
    }
}

struct PassportKeyboardDoneButton: View {
    var body: some View {
        Button("Done") {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
        .fontWeight(.semibold)
    }
}

/// Decides whether a tap is outside an editable or interactive UIKit control.
/// Walking the ancestor chain also covers UIKit's private subviews inside a text field.
enum KeyboardDismissPolicy {
    static func shouldDismiss(for touchedView: UIView?) -> Bool {
        var candidate = touchedView

        while let view = candidate {
            if view is UITextField || view is UITextView || view is UISearchBar || view is UIControl {
                return false
            }
            candidate = view.superview
        }

        return true
    }
}

@MainActor
private final class KeyboardDismissController: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissController()

    private var recognizers: [ObjectIdentifier: UITapGestureRecognizer] = [:]

    func install(in window: UIWindow?) {
        recognizers = recognizers.filter { $0.value.view != nil }
        guard let window else { return }

        let windowID = ObjectIdentifier(window)
        guard recognizers[windowID] == nil else { return }

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        window.addGestureRecognizer(recognizer)
        recognizers[windowID] = recognizer
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        KeyboardDismissPolicy.shouldDismiss(for: touch.view)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    @objc private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private final class KeyboardDismissInstallerUIView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        KeyboardDismissController.shared.install(in: window)
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = KeyboardDismissInstallerUIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        KeyboardDismissController.shared.install(in: uiView.window)
    }
}

extension View {
    func passportContentWidth(_ width: CGFloat = 760) -> some View {
        frame(maxWidth: width, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Keeps normal control taps working while dismissing the keyboard from blank-space taps.
    func passportDismissesKeyboardOnTap() -> some View {
        background(KeyboardDismissInstaller().frame(width: 0, height: 0))
    }

    func passportCollapsingTitle(_ title: String) -> some View {
        modifier(PassportCollapsingTitleModifier(title: title))
    }
}

struct PassportPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(PassportTheme.teal, in: RoundedRectangle(cornerRadius: 15))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct SectionEyebrow: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.5)
            .foregroundStyle(PassportTheme.muted)
    }
}

struct ItemArtwork: View {
    let item: ConsumableItem
    let photo: UIImage?
    var size: CGFloat = 54

    var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(item.category.assetName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.19)
                    .background(PassportTheme.pale)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .accessibilityHidden(true)
    }
}

struct ReplacementDueStatus: View {
    let item: ConsumableItem
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        if let due = item.nextDueDate {
            let overdue = item.isOverdue()
            VStack(alignment: alignment, spacing: 4) {
                Text(overdue ? "OVERDUE" : "DUE")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(overdue ? PassportTheme.ink : PassportTheme.teal)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 24)
                    .background(
                        overdue ? PassportTheme.amber.opacity(0.28) : PassportTheme.pale,
                        in: Capsule()
                    )
                Text("Due \(due.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption2)
                    .foregroundStyle(overdue ? PassportTheme.ink : PassportTheme.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                overdue
                    ? "Overdue, due \(due.formatted(.dateTime.month(.wide).day().year()))"
                    : "Due \(due.formatted(.dateTime.month(.wide).day().year()))"
            )
            .accessibilityIdentifier(overdue ? "replacementStatusOverdue" : "replacementStatusDue")
        }
    }
}

struct ItemRow: View {
    @EnvironmentObject private var store: PassportStore
    let item: ConsumableItem

    var body: some View {
        HStack(spacing: 13) {
            ItemArtwork(item: item, photo: store.photo(for: item))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(PassportTheme.ink)
                Text([item.brand, item.model.isEmpty ? item.size : item.model]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(PassportTheme.muted)
                    .lineLimit(1)
                Text(item.room)
                    .font(.caption2)
                    .foregroundStyle(PassportTheme.muted)
            }
            Spacer(minLength: 8)
            ReplacementDueStatus(item: item, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}
