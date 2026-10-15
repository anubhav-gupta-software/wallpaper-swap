//
//  HistoryView.swift
//  WallpaperSwap
//

import SwiftUI
import UIKit

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var filter: SwapDirection?
    @State private var selected: Swap?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var visible: [Swap] {
        guard let filter else { return model.swaps }
        return model.swaps.filter { $0.direction == filter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(Ink.serif(34))
                .foregroundStyle(Ink.text)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ChoiceChip(title: "All", isSelected: filter == nil) { filter = nil }
                    ChoiceChip(title: "Received", isSelected: filter == .received) { filter = .received }
                    ChoiceChip(title: "Sent", isSelected: filter == .sent) { filter = .sent }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }

            if visible.isEmpty {
                Spacer()
                Text(model.swaps.isEmpty ? "Photos you send and receive will gather here." : "Nothing in this filter.")
                    .font(.body)
                    .foregroundStyle(Ink.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(visible) { swap in
                            Button {
                                selected = swap
                            } label: {
                                cell(swap)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Use on my screen") { model.useOnMyScreen(swap) }
                                Button("Delete", role: .destructive) { model.delete(swap) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await model.refresh(reportErrors: true)
                }
            }
        }
        .sheet(item: $selected) { swap in
            HistoryDetail(swap: swap)
        }
    }

    private func cell(_ swap: Swap) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SwapThumb(swap: swap)
                .frame(height: 210)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(model.caption(for: swap))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Ink.text)
                .lineLimit(1)
            Text(swap.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(Ink.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SwapThumb: View {
    let swap: Swap
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Ink.raised
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .task(id: swap.id) {
            image = WallpaperStore.shared.thumbnail(for: swap)
        }
    }
}

private struct HistoryDetail: View {
    let swap: Swap
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack {
                    Ink.surface
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        ProgressView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 20)

                Text(model.caption(for: swap))
                    .font(Ink.serif(24))
                    .foregroundStyle(Ink.text)
                Text(swap.createdAt.formatted(date: .complete, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(Ink.secondary)

                VStack(spacing: 10) {
                    Button("Use on my screen") {
                        model.useOnMyScreen(swap)
                    }
                    .buttonStyle(FillButtonStyle())
                    Button("Save to Photos") {
                        guard let image else { return }
                        Task { await model.saveToPhotos(image) }
                    }
                    .buttonStyle(FillButtonStyle(prominent: false))
                    Button("Delete", role: .destructive) {
                        confirmDelete = true
                    }
                    .foregroundStyle(Ink.accent)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .background(Ink.background)
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete this photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    model.delete(swap)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                image = WallpaperStore.shared.image(relativePath: swap.imageFile)
            }
        }
        .preferredColorScheme(.dark)
        .tint(Ink.accent)
        .modelErrorAlert()
    }
}
