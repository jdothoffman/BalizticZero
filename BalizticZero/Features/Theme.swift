import SwiftUI

/// Black with one rose gold accent. Everything else comes from the system's semantic colors.
enum Theme {
    /// Pure black behind every screen.
    static let background = Color.black
    /// Raised surface for rows and panels, a faintly warm near-black so it sits with the accent.
    static let surface = Color(red: 0.078, green: 0.067, blue: 0.071)
    /// Hairline borders and dividers, a whisper of rose gold.
    static let hairline = accent.opacity(0.14)
    /// Rose gold (#E0A795). Used for the tint and for direction calls only.
    static let accent = Color(red: 0.878, green: 0.655, blue: 0.584)
    /// Warm amber for advisor verdicts that ask the shooter to check an input.
    static let caution = Color(red: 0.949, green: 0.722, blue: 0.341)

    static let cornerRadius: CGFloat = 12
}

extension View {
    /// Hides the stock grouped background so forms sit on the theme background.
    func themedForm() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background)
    }

    /// Row background for a form or list section.
    func themedRows() -> some View {
        listRowBackground(Theme.surface)
    }
}

/// Small tracked uppercase label for section headers and readout captions.
struct SectionLabel: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(.secondary)
    }
}

/// Bordered surface that groups content outside of a Form.
struct Panel<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                SectionLabel(title)
                    .padding(.horizontal, 4)
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline)
            )
        }
    }
}

/// Label and value pairs with hairline dividers, inside a panel.
struct DataPanel: View {
    var title: String?
    let rows: [(label: String, value: String)]

    var body: some View {
        Panel(title: title) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 1)
                        .padding(.leading, 14)
                }
                HStack {
                    Text(row.label)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(row.value)
                        .monospacedDigit()
                }
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
        }
    }
}
