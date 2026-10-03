---
name: liquid-glass-music-player
description: Specialized skill for designing and building cutting-edge Apple iOS 26+ Liquid Glass Music Player interfaces and audio handoff applications in SwiftUI. Covers Liquid Glass navigation and controls (.glassEffect, GlassEffectContainer, glassEffectID), MiniPlayer-to-Fullscreen transitions, dynamic mesh artwork ambient backdrops, fluid audio scrubbers, safe volume sliders, haptic feedback, and audio device picker sheets.
---

# Liquid Glass Music Player Skill (iOS 26+ & SwiftUI)

Specialized guide for building modern, high-end music player applications (like Spotify, Apple Music, and Castlie) featuring Apple's **Liquid Glass** dynamic material system, fluid physics, and tactile micro-interactions in SwiftUI.

---

## 1. Liquid Glass Design System Rules (iOS 26+)

### Core Principles
1. **Controls & Navigation Only**: Liquid Glass is a material for floating functional controls (dock, miniplayer, transport buttons, volume sliders, device selectors). **Never** apply glass to content itself (album grids, list rows, static lyric text).
2. **Dynamic Lensing & Refraction**: The material reacts to light, device motion, and underlying blurred album artwork.
3. **Containerized Morphing**: Group interactive glass controls inside `GlassEffectContainer` to allow them to visually merge and morph seamlessly.
4. **Availability & Fallbacks**: Always provide backward compatibility for iOS < 26 using `.ultraThinMaterial`.

### Essential API Signatures (iOS 26+)
```swift
// Single glass element
.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))

// Grouped glass container with shared refraction and morphing
GlassEffectContainer(spacing: 16) {
    HStack(spacing: 20) {
        Button(action: { /* Previous */ }) {
            Image(systemName: "backward.fill")
        }
        .buttonStyle(.glass)
        
        Button(action: { /* Play/Pause */ }) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
        }
        .buttonStyle(.glassProminent)
        .glassEffectID("playPauseButton", in: animationNamespace)
        
        Button(action: { /* Next */ }) {
            Image(systemName: "forward.fill")
        }
        .buttonStyle(.glass)
    }
}
```

### Backward Compatibility Helper
```swift
extension View {
    @ViewBuilder
    func adaptiveGlassSurface(cornerRadius: CGFloat = 24, interactive: Bool = true) -> some View {
        if #available(iOS 26, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )
        }
    }
}
```

---

## 2. Music Player Architecture & Components

### A. Floating MiniPlayer ➔ Fullscreen NowPlaying
* **MiniPlayer**: Floats 8–16pt above the bottom bar, utilizing `.adaptiveGlassSurface(cornerRadius: 22)`.
* **Expansion Interaction**: Tap or drag up triggers `.matchedGeometryEffect` with spring physics `.spring(response: 0.38, dampingRatio: 0.82)`.
* **Cover Art Continuity**: Album thumbnail morphs into the full-size 320x320 hero image with dynamic shadow tinting matching dominant artwork color.

### B. Dynamic Ambient Glow Backdrop
Create an immersive depth effect beneath the glass controls using the track's palette:
```swift
ZStack {
    // Underlying blurred ambient glow
    Color.black.ignoresSafeArea()
    
    GeometryReader { proxy in
        Circle()
            .fill(dominantArtworkColor.opacity(0.6))
            .frame(width: proxy.size.width * 1.2)
            .blur(radius: 90)
            .offset(x: -proxy.size.width * 0.2, y: -proxy.size.height * 0.15)
        
        Circle()
            .fill(secondaryArtworkColor.opacity(0.45))
            .frame(width: proxy.size.width * 1.1)
            .blur(radius: 110)
            .offset(x: proxy.size.width * 0.3, y: proxy.size.height * 0.3)
    }
    .ignoresSafeArea()
    
    // Main Player UI Floating above
}
```

### C. Fluid Waveform & Scrubber Bar
* **Interactive Drag**: Thumb increases in size on touch (`scaleEffect(isDragging ? 1.4 : 1.0)`).
* **Smooth Interpolation**: Audio track time updates continuously without causing full-view body re-renders.
* **Haptic Scrubbing**: Trigger `.sensoryFeedback(.selection, trigger: currentSecondBucket)` as user scrubs through track milestones.

### D. Safe Volume Handoff Slider
Specifically designed for volume management across devices (AirPlay / Spotify Connect / Local):
* **Safe Volume Ceiling**: Clearly demarcated threshold indicator (e.g., 75% limit) with color shift (accent ➔ orange ➔ cautionary red).
* **Handoff Lock / Confirmation**: Prevents accidental sudden high-volume handoff to external speakers.
* **Touch Expansion**: Width/height swells dynamically while dragging, returning to standard pill shape on release.

---

## 3. Micro-Interactions & Haptics Checklist

1. **Play/Pause Tap**: `.sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: isPlaying)`
2. **Next/Previous Track**: Snappy spring transition with horizontal slide and cover bounce.
3. **Device Switch (Handoff)**: Soft notification haptic `.sensoryFeedback(.success, trigger: activeDeviceId)`.
4. **Volume Safety Limit Reached**: Rigid haptic `.sensoryFeedback(.warning, trigger: volumeExceededWarning)`.

---

## 4. Performance Guidelines

* **Decouple Fast Timers**: Never run 60 FPS playback timers directly against high-level `@Observable` root objects. Keep scrubber state localized to the scrubber subview.
* **Avoid Stacked Blurs**: Do not place multiple `.glassEffect()` modifiers directly inside one another without a `GlassEffectContainer`; each independent glass context creates an extra GPU refraction pass.
* **Accessibility**: Always test with "Reduce Transparency" enabled (`@Environment(\.accessibilityReduceTransparency)`). Provide an opaque or high-contrast background fallback.
