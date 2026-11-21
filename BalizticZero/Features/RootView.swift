import SwiftUI

struct NumericField: View {
    let title: String
    @Binding var value: Double
    let unit: String
    var decimals: Int = 1

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(0...decimals)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 36, alignment: .leading)
            }
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
            }
        }
        .task {
            if store == nil {
                store = CalculatorStore(context: modelContext)
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
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text("Before you shoot")
                .font(.largeTitle.bold())
            Text("Baliztic Zero is a point-mass ballistic estimate. Wind, muzzle velocity, and the bullet’s real drag all move the impact.")
                .font(.body)
            Text("Check every solution on a known range before you trust it past 500 yards. Do not aim at anything you cannot afford to miss.")
                .font(.body)
            Spacer()
            Button(action: acknowledge) {
                Text("I understand")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .interactiveDismissDisabled()
    }
}
