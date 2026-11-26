import SwiftUI

struct NumericField: View {
    let title: String
    @Binding var value: Double
    let unit: String
    var decimals: Int = 1

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(0...decimals)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 36, alignment: .leading)
            }
        } label: {
            Text(title)
                .foregroundStyle(.secondary)
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
    @State private var store: CalculatorStore?

    var body: some View {
        Group {
            if let store {
                MainTabView(store: store)
            } else {
                ProgressView("Preparing calculator")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            }
        }
        .task {
            if store == nil {
                store = CalculatorStore(context: modelContext, weatherProvider: WeatherKitProvider())
            }
        }
        .fullScreenCover(isPresented: disclaimerPresented) {
            DisclaimerView {
                hasAcceptedDisclaimer = true
            }
        }
    }

    private var disclaimerPresented: Binding<Bool> {
        Binding(
            get: { store != nil && !hasAcceptedDisclaimer },
            set: { _ in }
        )
    }
}

struct MainTabView: View {
    @Bindable var store: CalculatorStore

    var body: some View {
        TabView {
            NavigationStack {
                ShotView(store: store)
            }
            .tabItem { Label("Shot", systemImage: "scope") }

            NavigationStack {
                EnvironmentView(store: store)
            }
            .tabItem { Label("Conditions", systemImage: "cloud.sun") }

            NavigationStack {
                LoadListView(store: store)
            }
            .tabItem { Label("Load", systemImage: "circle.circle") }

            NavigationStack {
                SolutionView(store: store)
            }
            .tabItem { Label("Solution", systemImage: "target") }

            NavigationStack {
                TrajectoryTableView(store: store)
            }
            .tabItem { Label("Table", systemImage: "list.number") }
        }
        .task(id: store.inputFingerprint) {
            store.recompute()
        }
    }
}

struct DisclaimerView: View {
    var acknowledge: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 32, height: 3)
            Text("Before you shoot")
                .font(.largeTitle.weight(.bold))
            Text("Baliztic Zero is a point-mass ballistic estimate. Wind, muzzle velocity, and the bullet’s real drag all move the impact.")
                .foregroundStyle(.secondary)
            Text("Check every solution on a known range before you trust it past 500 yards. Do not aim at anything you cannot afford to miss.")
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: acknowledge) {
                Text("I understand")
                    .font(.headline)
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }
}
