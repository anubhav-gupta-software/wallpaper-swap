//
//  CropView.swift
//  WallpaperSwap
//

import SwiftUI
import UIKit

struct CropView: View {
    let image: UIImage
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var startScale: CGFloat = 1
    @State private var startOffset: CGSize = .zero
    @State private var showGrid = true

    var body: some View {
        GeometryReader { geo in
            let crop = geo.size
            ZStack {
                Color.black
                framedPhoto(in: crop)
                if showGrid {
                    grid(in: crop)
                        .allowsHitTesting(false)
                }
                VStack {
                    topBar
                    Spacer()
                    bottomBar(in: crop)
                }
                .padding(.horizontal, 20)
                .padding(.top, geo.safeAreaInsets.top + 8)
                .padding(.bottom, geo.safeAreaInsets.bottom + 12)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .modelErrorAlert()
    }

    private func framedPhoto(in crop: CGSize) -> some View {
        let fill = CropGeometry.fillScale(imageSize: image.size, cropSize: crop)
        let displayed = CGSize(
            width: image.size.width * fill * scale,
            height: image.size.height * fill * scale
        )
        return Image(uiImage: image)
            .resizable()
            .frame(width: displayed.width, height: displayed.height)
            .position(x: crop.width / 2 + offset.width, y: crop.height / 2 + offset.height)
            .gesture(drag(in: crop).simultaneously(with: magnify(in: crop)))
            .onTapGesture(count: 2) {
                scale = 1
                offset = .zero
                startScale = 1
                startOffset = .zero
            }
            .accessibilityLabel("Crop. Pinch to zoom, drag to move. Double tap to reset.")
            .accessibilityAdjustableAction { direction in
                let next = direction == .increment ? scale + 0.25 : scale - 0.25
                scale = min(max(next, 1), 5)
                offset = CropGeometry.clampedOffset(
                    offset: offset,
                    imageSize: image.size,
                    cropSize: crop,
                    scale: scale
                )
                startScale = scale
                startOffset = offset
            }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.body.weight(.semibold))
                .foregroundStyle(Ink.text)
            Spacer()
            Button(showGrid ? "Hide grid" : "Grid") {
                showGrid.toggle()
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Ink.text)
        }
        .padding(.vertical, 8)
    }

    private func bottomBar(in crop: CGSize) -> some View {
        VStack(spacing: 12) {
            Text("Pinch and drag. The clock sits over the top of the Lock Screen, so keep faces a little lower.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 1)

            Button {
                commit(in: crop)
            } label: {
                Group {
                    if model.isWorking {
                        ProgressView()
                            .tint(Ink.onAccent)
                    } else {
                        Text(buttonTitle)
                    }
                }
            }
            .buttonStyle(FillButtonStyle())
            .disabled(model.isWorking || model.pairing?.isConfirmed != true)
        }
        .padding(16)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var buttonTitle: String {
        guard let pairing = model.pairing, pairing.isConfirmed else {
            return "Waiting for them"
        }
        if pairing.transport == .local, model.mirrorSends {
            return "Use on my screen"
        }
        return "Send to \(pairing.displayName)"
    }

    private func commit(in crop: CGSize) {
        let rendered = WallpaperRenderer.render(image: image, viewSize: crop, scale: scale, offset: offset)
        Task {
            await model.send(rendered)
            if model.lastError == nil {
                dismiss()
            }
        }
    }

    private func drag(in crop: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: startOffset.width + value.translation.width,
                    height: startOffset.height + value.translation.height
                )
                offset = CropGeometry.clampedOffset(
                    offset: proposed,
                    imageSize: image.size,
                    cropSize: crop,
                    scale: scale
                )
            }
            .onEnded { _ in
                startOffset = offset
            }
    }

    private func magnify(in crop: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let next = min(max(startScale * value.magnification, 1), 5)
                scale = next
                offset = CropGeometry.clampedOffset(
                    offset: offset,
                    imageSize: image.size,
                    cropSize: crop,
                    scale: next
                )
            }
            .onEnded { _ in
                startScale = scale
                startOffset = offset
            }
    }

    private func grid(in crop: CGSize) -> some View {
        Path { path in
            for index in 1...2 {
                let fraction = CGFloat(index) / 3
                path.move(to: CGPoint(x: crop.width * fraction, y: 0))
                path.addLine(to: CGPoint(x: crop.width * fraction, y: crop.height))
                path.move(to: CGPoint(x: 0, y: crop.height * fraction))
                path.addLine(to: CGPoint(x: crop.width, y: crop.height * fraction))
            }
        }
        .stroke(Color.white.opacity(0.4), lineWidth: 0.7)
    }
}
