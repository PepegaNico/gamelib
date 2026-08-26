import SwiftUI

struct StatChip: View {
    let systemImage: String
    let label: String

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.secondarySystemBackground), in: Capsule())
    }
}
