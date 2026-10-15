//
//  Theme.swift
//  WallpaperSwap
//

import SwiftUI

enum Ink {
    static let background = Color(red: 0.047, green: 0.043, blue: 0.039)
    static let surface = Color(red: 0.090, green: 0.086, blue: 0.078)
    static let raised = Color(red: 0.145, green: 0.129, blue: 0.114)
    static let line = Color(red: 0.27, green: 0.24, blue: 0.21)
    static let text = Color(red: 0.965, green: 0.945, blue: 0.906)
    static let secondary = Color(red: 0.64, green: 0.60, blue: 0.54)
    static let accent = Color(red: 1.0, green: 0.302, blue: 0.180)
    static let onAccent = Color(red: 0.145, green: 0.055, blue: 0.035)
    static let gold = Color(red: 0.894, green: 0.761, blue: 0.478)

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

struct FillButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(prominent ? Ink.onAccent : Ink.text)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .padding(.horizontal, 16)
            .background(
                prominent ? Ink.accent : Ink.raised,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.84 : 1)
    }
}
