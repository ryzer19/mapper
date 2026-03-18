import SwiftUI

struct PersonaliseView: View {
    @EnvironmentObject var userStore: UserStore

    var body: some View {
        List {

            // MARK: - Theme
            Section(header: Text("Theme")) {
                Toggle(isOn: $userStore.isDarkMode) {
                    Label {
                        Text(userStore.isDarkMode ? "Dark Mode" : "Light Mode")
                    } icon: {
                        Image(systemName: userStore.isDarkMode ? "moon.fill" : "sun.max.fill")
                            .foregroundStyle(userStore.isDarkMode ? .indigo : .orange)
                    }
                }
                .tint(.blue)
            }

            // MARK: - Map Style (adapts to theme)
            Section(
                header: Text("Map Style"),
                footer: Text(userStore.isDarkMode
                    ? "Choose a dark background style."
                    : "Choose a light background style.")
            ) {
                if userStore.isDarkMode {
                    StyleGrid(isDark: true) {
                        ForEach(DarkMapStyle.allCases) { style in
                            DarkStyleCard(
                                style: style,
                                isSelected: userStore.darkMapStyle == style,
                                lineColour: userStore.lineColour
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    userStore.darkMapStyle = style
                                }
                            }
                        }
                    }
                } else {
                    StyleGrid(isDark: false) {
                        ForEach(LightMapStyle.allCases) { style in
                            LightStyleCard(
                                style: style,
                                isSelected: userStore.lightMapStyle == style,
                                lineColour: userStore.lineColour
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    userStore.lightMapStyle = style
                                }
                            }
                        }
                    }
                }
            }

            // MARK: - Line Colour
            Section(header: Text("Driven Line Colour")) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 6),
                    spacing: 16
                ) {
                    ForEach(LineColour.allCases) { colour in
                        ColourDot(
                            colour: colour,
                            isSelected: userStore.lineColour == colour
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                userStore.lineColour = colour
                            }
                        }
                    }
                }
                .padding(.vertical, 10)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                // Live preview
                LinePreview(
                    colour: userStore.lineColour,
                    opacity: userStore.lineOpacity,
                    isDark: userStore.isDarkMode
                )
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // MARK: - Opacity
            Section(header: Text("Line Opacity")) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Subtle").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(userStore.lineOpacity * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Bold").font(.caption).foregroundStyle(.secondary)
                    }
                    Slider(value: $userStore.lineOpacity, in: 0.2...1.0, step: 0.05)
                        .tint(userStore.lineColour.swiftColour)
                }
                .padding(.vertical, 4)
            }

            // MARK: - Labels
            Section(header: Text("Map Labels")) {
                Toggle(isOn: $userStore.showMapLabels) {
                    Label("Show Road Names", systemImage: "text.magnifyingglass")
                }
                .tint(.blue)
            }

            // MARK: - Pulse
            Section(
                header: Text("Active Segment"),
                footer: Text("Pulses the line currently being drawn as you drive.")
            ) {
                Toggle(isOn: $userStore.pulseActive) {
                    Label("Pulse Animation", systemImage: "waveform.path")
                }
                .tint(.blue)
            }
        }
        .navigationTitle("Personalise")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Style Grid container

struct StyleGrid<Content: View>: View {
    let isDark: Bool
    @ViewBuilder let content: Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                  spacing: 10) {
            content
        }
        .padding(.vertical, 6)
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .listRowBackground(Color.clear)
    }
}

// MARK: - Dark Style Card

struct DarkStyleCard: View {
    let style: DarkMapStyle
    let isSelected: Bool
    let lineColour: LineColour
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(style.cardBG)
                        .frame(height: 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? Color.blue : Color.white.opacity(0.08),
                                        lineWidth: isSelected ? 2.5 : 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)

                    // Road grid preview
                    ZStack {
                        // Horizontal road
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(style.roadColour)
                            .frame(width: 60, height: 4)
                        // Vertical road
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(style.roadColour)
                            .frame(width: 4, height: 60)
                        // Driven line
                        DrawnLine()
                            .stroke(lineColour.swiftColour.opacity(0.85),
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 52, height: 52)
                    }

                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue.opacity(0.12))
                    }
                }

                Text(style.label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(style.description)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Light Style Card

struct LightStyleCard: View {
    let style: LightMapStyle
    let isSelected: Bool
    let lineColour: LineColour
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(style.cardBG)
                        .frame(height: 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? Color.blue : Color.black.opacity(0.08),
                                        lineWidth: isSelected ? 2.5 : 1)
                        )
                        .shadow(color: .black.opacity(0.10), radius: 6, y: 2)

                    ZStack {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(style.roadColour)
                            .frame(width: 60, height: 4)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(style.roadColour)
                            .frame(width: 4, height: 60)
                        DrawnLine()
                            .stroke(lineColour.swiftColour.opacity(0.85),
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 52, height: 52)
                    }

                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue.opacity(0.08))
                    }
                }

                Text(style.label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(style.description)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Colour Dot

struct ColourDot: View {
    let colour: LineColour
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(colour.swiftColour)
                    .frame(width: 34, height: 34)
                    .shadow(color: colour.swiftColour.opacity(0.45), radius: 4, y: 2)
                if isSelected {
                    Circle()
                        .strokeBorder(colour.swiftColour, lineWidth: 3)
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(colour == .white ? .black.opacity(0.6) : .black.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Line Preview

struct LinePreview: View {
    let colour: LineColour
    let opacity: Double
    let isDark: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isDark
                      ? Color(red: 0.08, green: 0.08, blue: 0.10)
                      : Color(red: 0.93, green: 0.93, blue: 0.95))

            // Road strip
            RoundedRectangle(cornerRadius: 2)
                .fill(isDark
                      ? Color(white: 0.22)
                      : Color(white: 0.75))
                .frame(height: 7)
                .padding(.horizontal, 24)

            // Glow
            RoundedRectangle(cornerRadius: 3)
                .fill(colour.swiftColour.opacity(opacity * 0.30))
                .frame(height: 16)
                .padding(.horizontal, 24)

            // Core line
            RoundedRectangle(cornerRadius: 2)
                .fill(colour.swiftColour.opacity(opacity))
                .frame(height: 4)
                .padding(.horizontal, 24)
        }
    }
}

// MARK: - Drawn Line Shape

struct DrawnLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.minX + 6,  y: rect.maxY - 8))
        p.addLine(to: CGPoint(x: rect.midX,       y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - 8,   y: rect.minY + 10))
        return p
    }
}
