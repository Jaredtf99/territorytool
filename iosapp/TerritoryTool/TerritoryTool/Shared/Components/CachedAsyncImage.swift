import SwiftUI
import Nuke
import NukeUI

/// A reusable component that loads and caches images using Nuke.
/// Handles loading, success, and failure states with appropriate UI for each.
struct CachedAsyncImage<Content: View, Placeholder: View, ErrorView: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let errorView: () -> ErrorView
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder errorView: @escaping () -> ErrorView
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self.errorView = errorView
    }
    
    var body: some View {
        if let url = url {
            LazyImage(url: url) { state in
                if let image = state.image {
                    // Success state - image loaded
                    content(image)
                } else if state.error != nil {
                    // Error state - failed to load image
                    errorView()
                } else {
                    // Loading state - image is being fetched
                    placeholder()
                }
            }
            // Configure Nuke pipeline with caching
            .pipeline(ImagePipeline.shared)
            // Enable disk cache
            .processors([])
        } else {
            // No URL provided - show error view
            errorView()
        }
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView>, ErrorView == DefaultErrorView {
    /// Simplified initializer with default placeholder and error view
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.url = url
        self.content = content
        self.placeholder = {
            ProgressView()
        }
        self.errorView = {
            DefaultErrorView()
        }
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView>, ErrorView == DefaultErrorView {
    /// Most simplified initializer - just pass the URL
    init(url: URL?) {
        self.url = url
        self.content = { image in image }
        self.placeholder = {
            ProgressView()
        }
        self.errorView = {
            DefaultErrorView()
        }
    }
}

// MARK: - Default Error View

struct DefaultErrorView: View {
    var body: some View {
        Color.secondary.opacity(0.1)
            .overlay(
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.secondary.opacity(0.3))
            )
    }
}
