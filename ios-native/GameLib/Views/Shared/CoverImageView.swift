import SwiftUI

/// Async-loaded game cover with a placeholder while loading/on failure —
/// the native equivalent of cached_network_image's placeholder/error
/// widgets. No disk-cache layer yet in Phase 1; URLSession's default cache
/// covers the common case of scrolling back to an already-seen cover.
struct CoverImageView: View {
    let url: URL
    var cornerRadius: CGFloat = 8

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                placeholder
            case .empty:
                placeholder.overlay(ProgressView())
            @unknown default:
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.secondarySystemBackground))
            .overlay(Image(systemName: "gamecontroller").foregroundStyle(.secondary))
    }
}
