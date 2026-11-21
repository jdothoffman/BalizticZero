import Foundation

/// Placeholder for the later AI layer. The solver does not call this.
protocol BallisticAdvising: Sendable {
    var isAvailable: Bool { get }
    func explain(solution: FiringSolution) async -> String
}

struct UnavailableBallisticAdvisor: BallisticAdvising {
    let isAvailable = false

    func explain(solution: FiringSolution) async -> String {
        "AI advisor is not available yet."
    }
}
