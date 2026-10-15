//
//  HomeView.swift
//  WallpaperSwap
//

import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct EditableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showPair = false
    @State private var showSettings = false
    @State private var chrome: PhonePreview.Chrome = .lock
    @State private var pickerItem: PhotosPickerItem?
    @State private var cropImage: EditableImage?
    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 0) {
            header
            PhonePreview(
                image: model.currentImage,
                chrome: chrome,
                emptyTitle: emptyTitle,
                emptyDetail: emptyDetail
            )
            .padding(.horizontal, 48)
            .padding(.top, 4)
            .frame(minHeight: 240, maxHeight: .infinity)

            if model.currentImage != nil {
                HStack(spacing: 8) {
                    ChoiceChip(title: "Lock Screen", isSelected: chrome == .lock) { chrome = .lock }
                    ChoiceChip(title: "Home Screen", isSelected: chrome == .home) { chrome = .home }
                }
                .padding(.top, 14)
            }

            ScreenCaption(title: captionTitle, detail: captionDetail)
                .padding(.top, 14)

            if let pairing = model.pairing, !pairing.isConfirmed {
                Text(InviteCode.grouped(pairing.code))
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .foregroundStyle(Ink.gold)
                    .padding(.top, 8)
                    .accessibilityLabel("Invite code \(InviteCode.grouped(pairing.code))")
            }

            actionArea
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showPair) {
            PairView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(item: $cropImage) { item in
            CropView(image: item.image)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onImage: { image in
                    showCamera = false
                    cropImage = EditableImage(image: ImagePrep.prepare(image))
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Wallpaper Swap")
                    .font(Ink.serif(22))
                    .foregroundStyle(Ink.text)
                Text(headerDetail)
                    .font(.caption)
                    .foregroundStyle(Ink.secondary)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Ink.text)
                    .frame(width: 44, height: 44)
                    .background(Ink.raised, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var actionArea: some View {
        VStack(spacing: 10) {
            if model.pairing?.isConfirmed == true {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text(sendTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Ink.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Ink.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .accessibilityLabel(sendTitle)

                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            Task { await openCamera() }
                        } label: {
                            Image(systemName: "camera")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Ink.text)
                                .frame(width: 54, height: 54)
                                .background(Ink.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .accessibilityLabel("Take a photo")
                    }
                }
            } else {
                Button(model.pairing == nil ? "Pair with a friend" : "Share the code") {
                    showPair = true
                }
                .buttonStyle(FillButtonStyle())
            }

            Button("Try a sample photo") {
                model.useSample()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Ink.gold)
            .frame(minHeight: 36)

            if model.currentImage != nil {
                Button("How to set the real wallpaper") {
                    model.selectedTab = .guide
                }
                .font(.subheadline)
                .foregroundStyle(Ink.secondary)
            }

            if model.currentImage != nil, !WallpaperStore.shared.usesAppGroup {
                Text("Shortcuts can set this photo. The widget stays empty until App Group sharing is signed. The guide explains it.")
                    .font(.caption)
                    .foregroundStyle(Ink.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
    }

    private var sendTitle: String {
        if model.pairing?.transport == .local, model.mirrorSends {
            return "Frame a photo"
        }
        if let name = model.pairing?.displayName {
            return "Send to \(name)"
        }
        return "Send a photo"
    }

    private var headerDetail: String {
        switch model.syncMode {
        case .local: "On this iPhone"
        case .nearby: "Nearby"
        case .iCloud: "iCloud"
        }
    }

    private var emptyTitle: String {
        if model.pairing == nil { return "No pair yet" }
        if model.pairing?.isConfirmed == false { return "Waiting" }
        return "Nothing yet"
    }

    private var emptyDetail: String {
        if model.pairing == nil { return "Pair, or try a sample." }
        if let pairing = model.pairing, !pairing.isConfirmed { return "Share your code." }
        return "Their first photo will land here."
    }

    private var captionTitle: String {
        if let meta = model.currentMeta { return meta.caption }
        if let pairing = model.pairing {
            return pairing.isConfirmed ? pairing.displayName : "Code ready"
        }
        return "One friend"
    }

    private var captionDetail: String {
        if let meta = model.currentMeta {
            return meta.date.formatted(.relative(presentation: .named))
        }
        if let status = model.status, model.pairing != nil {
            return status
        }
        if model.pairing == nil {
            return "Send a photo. It becomes their wallpaper."
        }
        if model.pairing?.isConfirmed == true {
            return "Waiting for their first photo."
        }
        return "Keep the app open while they join."
    }

    private func load(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        do {
            guard let picked = try await item.loadTransferable(type: PickedPhoto.self) else {
                model.lastError = "Couldn't open that photo."
                return
            }
            cropImage = EditableImage(image: picked.image)
        } catch {
            model.lastError = "Couldn't open that photo."
        }
    }

    private func openCamera() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) {
                showCamera = true
            }
        default:
            model.lastError = "Camera access is off. You can still choose a photo from your library."
        }
    }
}
