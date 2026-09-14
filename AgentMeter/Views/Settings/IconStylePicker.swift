//
//  IconStylePicker.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Visual grid picker for selecting menu bar icon style
struct IconStylePicker: View {
    @Binding var selection: IconStyle
    let isColored: Bool
    var showsCodex: Bool = false
    var onSelectionChanged: ((IconStyle) -> Void)? = nil

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(IconStyle.allCases) { style in
                let isSelectable = IconStyle.isSelectable(style, isCodexUsageShown: showsCodex)
                IconStyleCard(
                    style: style,
                    isSelected: selection == style,
                    isColored: isColored,
                    showsCodex: showsCodex,
                    isLocked: !isSelectable
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isSelectable else { return }
                    selection = style
                    onSelectionChanged?(style)
                }
            }
        }
    }
}

/// Individual card showing icon style preview
struct IconStyleCard: View {
    let style: IconStyle
    let isSelected: Bool
    let isColored: Bool
    var showsCodex: Bool = false
    var isLocked: Bool = false

    /// Preview percentages to show
    private let previewPercentage: Double = 65
    private let previewWeeklyPercentage: Double = 45
    private let previewCodexSession: Double = 28
    private let previewCodexWeekly: Double = 18
    private let previewStatus: UsageStatus = .warning

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(height: 32)

                iconPreview
                    .scaleEffect(1.2)
                    .opacity(isLocked ? 0.45 : 1)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(3)
                        .background(.thinMaterial, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(4)
                }
            }

            HStack(spacing: 4) {
                Text(style.displayName)
                    .font(.caption)
                    .foregroundStyle(isSelected && !isLocked ? Color.accentColor : Color.primary)

                if isSelected && !isLocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .padding(8)
        .background(isSelected && !isLocked ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSelected && !isLocked ? Color.accentColor : Color.primary.opacity(0.12),
                    lineWidth: isSelected && !isLocked ? 2 : 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(style.displayName) icon style")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isLocked ? IconStyle.dualBarRequiredForCodexCaption : style.accessibilityDescription)
    }

    private var iconPreview: some View {
        Image(nsImage: MenuBarIconRenderer().render(
            percentage: previewPercentage,
            status: previewStatus,
            isLoading: false,
            isStale: false,
            iconStyle: style,
            weeklyPercentage: previewWeeklyPercentage,
            isColored: isColored,
            showsCodex: showsCodex && style == .dualBar,
            claudeSession: previewPercentage,
            claudeWeekly: previewWeeklyPercentage,
            codexSession: previewCodexSession,
            codexWeekly: previewCodexWeekly
        ))
            .renderingMode(isColored ? .original : .template)
            .foregroundStyle(.primary)
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selection: IconStyle = .battery
        @State private var isColored: Bool = true

        var body: some View {
            VStack {
                Text("Selected: \(selection.displayName)")
                    .padding()

                Picker("Icon color", selection: $isColored) {
                    Text("System").tag(false)
                    Text("Color").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                IconStylePicker(selection: $selection, isColored: isColored)
                    .padding()
            }
            .frame(width: 400)
        }
    }

    return PreviewWrapper()
}
