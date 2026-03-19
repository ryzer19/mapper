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

            // MARK: - Line Colour
            Section(header: Text("Driven Line Colour")) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 6),
                    spacing: 16
                ) {
                    ForEach(LineColour.allCases.filter { $0 != .custom }) { colour in
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

                // Custom colour picker
                HStack {
                    Label("Custom", systemImage: "paintpalette.fill")
                        .foregroundStyle(userStore.lineColour == .custom ? userStore.customLineColor : .primary)
                    Spacer()
                    if userStore.lineColour == .custom {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.blue)
                            .padding(.trailing, 8)
                    }
                    ColorPicker("", selection: Binding(
                        get: { userStore.customLineColor },
                        set: { newColor in
                            userStore.customLineColor = newColor
                            withAnimation(.spring(response: 0.3)) {
                                userStore.lineColour = .custom
                            }
                        }
                    ))
                    .labelsHidden()
                }

                // Live preview
                LinePreview(
                    colour: userStore.resolvedLineColor,
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
                        .tint(userStore.resolvedLineColor)
                }
                .padding(.vertical, 4)
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
    let colour: Color
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
                .fill(colour.opacity(opacity * 0.30))
                .frame(height: 16)
                .padding(.horizontal, 24)

            // Core line
            RoundedRectangle(cornerRadius: 2)
                .fill(colour.opacity(opacity))
                .frame(height: 4)
                .padding(.horizontal, 24)
        }
    }
}

