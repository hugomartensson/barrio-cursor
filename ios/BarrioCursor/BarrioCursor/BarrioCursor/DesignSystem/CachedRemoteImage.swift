import SwiftUI
import UIKit

/// In-memory image cache for remote URLs (shared across the app).
private final class RemoteImageCache {
    static let shared = RemoteImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    private init() {
        cache.countLimit = 200
    }
    func image(for url: NSURL) -> UIImage? { cache.object(forKey: url) }
    func insert(_ image: UIImage, for url: NSURL) { cache.setObject(image, forKey: url) }
}

/// Loads HTTPS images with `URLSession.shared`, memory cache, and one retry — avoids flaky `AsyncImage` on some OS versions.
struct CachedRemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    /// Shown while loading or on failure before placeholder
    var placeholder: AnyView
    var failure: AnyView

    @State private var uiImage: UIImage?
    @State private var loadFailed = false
    @State private var taskGeneration = 0

    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> some View = {
            Rectangle().fill(Color.portalMuted).overlay { ProgressView() }
        },
        @ViewBuilder failure: () -> some View = {
            Rectangle().fill(Color.portalMuted)
        }
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = AnyView(placeholder())
        self.failure = AnyView(failure())
    }

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if loadFailed {
                failure
            } else {
                placeholder
            }
        }
        .task(id: url?.absoluteString ?? "") {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        loadFailed = false
        uiImage = nil
        guard let url, url.scheme == "http" || url.scheme == "https" else {
            loadFailed = true
            return
        }
        let key = url as NSURL
        if let cached = RemoteImageCache.shared.image(for: key) {
            uiImage = cached
            return
        }
        for attempt in 0 ..< 2 {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                    if attempt == 1 { loadFailed = true }
                    continue
                }
                guard let image = UIImage(data: data) else {
                    if attempt == 1 { loadFailed = true }
                    continue
                }
                RemoteImageCache.shared.insert(image, for: key)
                uiImage = image
                return
            } catch {
                if attempt == 1 { loadFailed = true }
            }
        }
    }
}
