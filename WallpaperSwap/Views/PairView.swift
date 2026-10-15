//
//  PairView.swift
//  WallpaperSwap
//

import SwiftUI
import UIKit

struct PairView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var friendName = ""
    @State private var codeEntry = ""
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let pairing = model.pairing {
                        paired(pairing)
                    } else {
                        modePicker
                        modeBody
                    }
                    if let status = model.status, !status.isEmpty {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(Ink.secondary)
                    }
                }
                .padding(20)
            }
            .background(Ink.background)
            .navigationTitle("Pair")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Ink.accent)
        .modelErrorAlert()
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How do you want to connect?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Ink.secondary)
            VStack(spacing: 8) {
                ForEach(SyncMode.allCases) { mode in
                    Button {
                        model.setSyncMode(mode)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: model.syncMode == mode ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(model.syncMode == mode ? Ink.accent : Ink.secondary)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(mode.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Ink.text)
                                Text(mode.blurb)
                                    .font(.footnote)
                                    .foregroundStyle(Ink.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(Ink.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var modeBody: some View {
        switch model.syncMode {
        case .local:
            localForm
        case .nearby:
            codeForm(
                createTitle: "Create a code",
                joinTitle: "Join with a code",
                footnote: "Both of you keep Wallpaper Swap open. Same Wi-Fi is the reliable case. This uses the local network only."
            )
        case .iCloud:
            codeForm(
                createTitle: "Create an iCloud code",
                joinTitle: "Join an iCloud code",
                footnote: "iCloud mode needs a paid Apple Developer Program membership, the iCloud entitlement, and a CloudKit index on Photo.room. Until then, use Nearby."
            )
        }
    }

    private var localForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Friend's name")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Ink.secondary)
            TextField("Maya", text: $friendName)
                .textInputAutocapitalization(.words)
                .font(Ink.serif(28))
                .foregroundStyle(Ink.text)
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }

            Toggle(isOn: Binding(
                get: { model.mirrorSends },
                set: { model.setMirror($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Also show photos I send")
                        .foregroundStyle(Ink.text)
                    Text("So you can try the wallpaper without a second phone.")
                        .font(.footnote)
                        .foregroundStyle(Ink.secondary)
                }
            }
            .tint(Ink.accent)

            Button("Pair on this iPhone") {
                model.pairLocally(partnerName: friendName)
                if model.pairing != nil { dismiss() }
            }
            .buttonStyle(FillButtonStyle())
        }
    }

    private func codeForm(createTitle: String, joinTitle: String, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(createTitle) {
                Task { await create() }
            }
            .buttonStyle(FillButtonStyle())
            .disabled(model.isWorking)

            Text("Or enter theirs")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Ink.secondary)
            TextField("AB3 K9Q", text: $codeEntry)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 28, weight: .medium, design: .monospaced))
                .foregroundStyle(Ink.gold)
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }

            Button(joinTitle) {
                Task { await join() }
            }
            .buttonStyle(FillButtonStyle(prominent: false))
            .disabled(model.isWorking || InviteCode.normalize(codeEntry).count != InviteCode.length)

            Text(footnote)
                .font(.footnote)
                .foregroundStyle(Ink.secondary)
        }
    }

    private func paired(_ pairing: Pairing) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(pairing.isConfirmed ? "Paired with \(pairing.displayName)" : "Waiting for your friend")
                .font(Ink.serif(32))
                .foregroundStyle(Ink.text)
            Text(pairing.transport.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Ink.gold)

            Button {
                UIPasteboard.general.string = InviteCode.grouped(pairing.code)
                copied = true
            } label: {
                Text(InviteCode.grouped(pairing.code))
                    .font(.system(size: 44, weight: .medium, design: .monospaced))
                    .foregroundStyle(Ink.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy code \(InviteCode.grouped(pairing.code))")

            if copied {
                Text("Copied.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Ink.secondary)
            }

            ShareLink(item: shareText(pairing)) {
                Label("Share code", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FillButtonStyle())

            if !pairing.isConfirmed {
                Text("Leave this open. They enter the code in Wallpaper Swap.")
                    .font(.footnote)
                    .foregroundStyle(Ink.secondary)
            }

            Button("Unpair", role: .destructive) {
                model.unpair()
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(Ink.accent)
        }
    }

    private func shareText(_ pairing: Pairing) -> String {
        "Join me on Wallpaper Swap. Code: \(InviteCode.grouped(pairing.code))"
    }

    private func create() async {
        do {
            _ = try await model.beginHosting()
        } catch {
            model.lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func join() async {
        do {
            try await model.join(code: codeEntry)
            dismiss()
        } catch {
            model.lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
