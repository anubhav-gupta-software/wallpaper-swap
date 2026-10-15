//
//  SettingsView.swift
//  WallpaperSwap
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draftName = ""
    @State private var confirmUnpair = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    nameBlock
                    syncBlock
                    if model.syncMode == .local {
                        mirrorBlock
                    }
                    if model.pairing != nil {
                        pairBlock
                    }
                    sharingBlock
                    Button("Replay the intro") {
                        model.showIntro = true
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Ink.text)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Ink.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("Version \(version)")
                        .font(.caption)
                        .foregroundStyle(Ink.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .background(Ink.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        model.updateName(draftName)
                        dismiss()
                    }
                }
            }
            .onAppear { draftName = model.name }
            .confirmationDialog("Unpair \(model.pairing?.displayName ?? "your friend")?", isPresented: $confirmUnpair, titleVisibility: .visible) {
                Button("Unpair", role: .destructive) { model.unpair() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Photos already in History stay on this iPhone.")
            }
        }
        .preferredColorScheme(.dark)
        .tint(Ink.accent)
        .modelErrorAlert()
    }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your name")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Ink.secondary)
            TextField("Your name", text: $draftName)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .font(Ink.serif(28))
                .foregroundStyle(Ink.text)
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
        }
    }

    private var syncBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sync")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Ink.secondary)
            ForEach(SyncMode.allCases) { mode in
                Button {
                    model.setSyncMode(mode)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.title)
                                .foregroundStyle(Ink.text)
                            Text(mode.blurb)
                                .font(.caption)
                                .foregroundStyle(Ink.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        if model.syncMode == mode {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Ink.accent)
                        }
                    }
                    .padding(14)
                    .background(Ink.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var mirrorBlock: some View {
        Toggle(isOn: Binding(
            get: { model.mirrorSends },
            set: { model.setMirror($0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Show photos I send")
                    .foregroundStyle(Ink.text)
                Text("On-device pairs only. Puts the framed photo on your screen too.")
                    .font(.caption)
                    .foregroundStyle(Ink.secondary)
            }
        }
        .tint(Ink.accent)
        .padding(14)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var pairBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pair")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Ink.secondary)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.pairing?.isConfirmed == true ? (model.pairing?.displayName ?? "") : "Waiting to join")
                        .foregroundStyle(Ink.text)
                    if let code = model.pairing?.code {
                        Text(InviteCode.grouped(code))
                            .font(.caption.monospaced())
                            .foregroundStyle(Ink.gold)
                    }
                }
                Spacer()
                Button("Unpair") { confirmUnpair = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Ink.accent)
            }
            .padding(14)
            .background(Ink.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var sharingBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Widget sharing")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Ink.secondary)
            Text(WallpaperStore.shared.usesAppGroup
                ? "The App Group is available. New photos can show up on the widgets."
                : "This install isn't signed with an App Group, so the widgets can't see photos yet. That's normal for a free Apple ID. Shortcuts still can. The README explains the paid switch.")
                .font(.subheadline)
                .foregroundStyle(Ink.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Ink.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
