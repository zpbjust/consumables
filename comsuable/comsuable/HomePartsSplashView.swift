import SwiftUI

struct HomePartsRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            if isShowingSplash {
                HomePartsSplashView()
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .task {
            guard isShowingSplash else { return }
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }

            if reduceMotion {
                isShowingSplash = false
            } else {
                withAnimation(.easeOut(duration: 0.28)) {
                    isShowingSplash = false
                }
            }
        }
    }
}

struct HomePartsSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    var body: some View {
        VStack(spacing: 18) {
            Image("WelcomeHome")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 124, height: 124)
                .padding(18)
                .background(
                    PassportTheme.pale,
                    in: RoundedRectangle(cornerRadius: 34, style: .continuous)
                )
                .scaleEffect(isPresented || reduceMotion ? 1 : 0.94)
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text("HomeParts")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(PassportTheme.ink)

                Text("HOME CARE, ORGANIZED")
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(PassportTheme.teal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PassportTheme.canvas.ignoresSafeArea())
        .preferredColorScheme(.light)
        .opacity(isPresented || reduceMotion ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("HomeParts")
        .accessibilityIdentifier("launchSplash")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                isPresented = true
            }
        }
    }
}

#Preview {
    HomePartsSplashView()
}
