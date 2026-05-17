//
//  CachedAsyncImage.swift
//  one
//
//  Drop-in AsyncImage replacement with cross-screen image caching.
//  Faz 3.3 (2026-04-26).
//
//  Why: SwiftUI's AsyncImage re-fetches every time the view re-mounts —
//  this causes flicker in scrollable feeds (Discovery, Circle, Archive).
//  CachedAsyncImage serves from `ImageCache.shared` first, so revisits
//  paint the previous result instantly while a fresh fetch happens silently.
//
//  Reduce Motion: the loading shimmer respects @Environment(\.accessibilityReduceMotion).
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
                    .transition(.opacity)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            // URL değiştiğinde eski görüntüyü hemen temizle, sonra yeni URL'yi yükle.
            // guard image == nil burada yoktu — url değişince eski fotoğraf takılı kalıyordu.
            image = nil
            guard url != nil else { return }
            await load()
        }
    }

    private func load() async {
        guard let url else { return }
        isLoading = true
        defer { isLoading = false }
        if let cached = await ImageCache.shared.image(for: url) {
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.18)) {
                    image = cached
                }
            }
        }
    }
}

// MARK: - Convenience: default Light Serenity skeleton placeholder

extension CachedAsyncImage where Placeholder == SerenitySkeleton {
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(url: url, content: content) { SerenitySkeleton() }
    }
}

// MARK: - AsyncImagePhase-style overload

/// Phase-aware variant of `CachedAsyncImage`. Drop-in replacement for
/// `AsyncImage(url:) { phase in switch phase { ... } }` patterns — keeps
/// existing call sites working while still serving from `ImageCache`.
struct CachedAsyncImagePhase<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content

    @State private var image: UIImage?
    @State private var hasFailed = false
    @State private var isLoading = false

    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    var body: some View {
        Group {
            if let image {
                content(.success(Image(uiImage: image)))
                    .transition(.opacity)
            } else if hasFailed {
                content(.failure(URLError(.badServerResponse)))
            } else {
                content(.empty)
            }
        }
        .task(id: url) {
            // URL değiştiğinde önceki görüntüyü temizle — aksi hâlde
            // aynı konuma farklı bir entry geldiğinde eski fotoğraf kalır.
            await MainActor.run { image = nil; hasFailed = false }
            isLoading = false
            await load()
        }
    }

    private func load() async {
        guard let url else {
            await MainActor.run { hasFailed = true }
            return
        }
        isLoading = true
        defer { isLoading = false }
        if let cached = await ImageCache.shared.image(for: url) {
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.18)) {
                    image = cached
                }
            }
        } else {
            await MainActor.run { hasFailed = true }
        }
    }
}

/// Soft warm-off-white shimmer that matches the Light Serenity aesthetic.
/// Use as a placeholder for any image-loading state.
struct SerenitySkeleton: View {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle()
            .fill(ONETokens.oneCream)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        ONETokens.oneCreamMid.opacity(0.45),
                        Color.clear
                    ]),
                    startPoint: .init(x: phase - 0.4, y: 0.5),
                    endPoint: .init(x: phase + 0.4, y: 0.5)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCard))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .linear(duration: 1.4).repeatForever(autoreverses: false)
                ) {
                    phase = 1.4
                }
            }
            .accessibilityHidden(true)
    }
}
