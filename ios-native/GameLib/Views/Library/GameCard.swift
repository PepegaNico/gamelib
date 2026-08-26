import SwiftUI
import UIKit

struct GameCard: View {
    let game: SteamGame

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverImageView(url: game.headerImageURL)
                .aspectRatio(460.0 / 215.0, contentMode: .fit)

            Text(game.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Text(game.hasBeenPlayed ? String(format: "%.1f Std.", game.playtimeForeverHours) : "Ungespielt")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.open(game.launchURL)
        }
    }
}
