---
alwaysApply: true
---
# 🎨 UI/UX Design Principles for AutoCapture (iOS 26)

You are designing UI/UX for AutoCapture iOS app. Follow these design principles for a professional, intuitive user experience.

## 🎯 Design Philosophy

### Professional Photography Focus
- **Clean Interface**: Minimal distractions for focused photography
- **Quick Access**: Essential controls easily accessible
- **Quality First**: UI supports high-quality image processing
- **Efficiency**: Streamlined workflows for professional use

### Modern iOS Design
- **Human Interface Guidelines**: Follow Apple’s latest iOS 26 guidance from the [Design Resources portal](https://developer.apple.com/design/resources/) so AutoCapture remains visually native.
- **Liquid Glass Surfaces**: Adopt the iOS 26 liquid glass materials for overlays, control trays, and toolbars to match Control Center and Lock Screen aesthetics.
- **Enhanced Accessibility**: Integrate VoiceOver rotor actions, Dynamic Type scaling, haptic affordances, and the iOS 26 contrast auditing workflow.
- **Responsive Layouts**: Support Stage Manager, Display Zoom, and multitasking using SwiftUI’s adaptive layout APIs (`ViewThatFits`, custom `Layout` types).

## 📱 Layout Principles

### Information Hierarchy
- **Primary Actions**: Most important controls prominently placed
- **Secondary Actions**: Less critical features in secondary positions
- **Progressive Disclosure**: Show complexity gradually
- **Visual Weight**: Use size, color, and position to guide attention

### Screen Real Estate
- **Camera View**: Maximize camera preview area
- **Editor View**: Dedicate space to canvas and tools
- **Settings**: Organize in logical groups with clear sections
- **Navigation**: Consistent navigation patterns throughout

### Touch Targets
- **Minimum Size**: 44x44 points minimum touch target
- **Adequate Spacing**: 8+ points between interactive elements
- **Thumb-Friendly**: Place primary actions in thumb reach
- **Visual Feedback**: Clear indication of touchable elements

## 🎨 Visual Design

### Color Palette
Use semantic system colors so the UI automatically adapts to liquid-glass transparency, vibrancy, and Dark Mode in iOS 26.
```swift
import SwiftUI

enum AutoCaptureColor {
    static let chrome = Color(uiColor: .secondarySystemBackground)
    static let accent = Color.cyan
    static let critical = Color.red
    static let success = Color.green
    static let warning = Color.orange

    static let label = Color(uiColor: .label)
    static let secondaryLabel = Color(uiColor: .secondaryLabel)
    static let fill = Color(uiColor: .tertiarySystemFill)
}
```

### Typography
```swift
// Font System
extension Font {
    static let autocaptureTitle = Font.largeTitle.weight(.bold)
    static let autocaptureHeadline = Font.headline.weight(.semibold)
    static let autocaptureBody = Font.body
    static let autocaptureCaption = Font.caption
    static let autocaptureButton = Font.body.weight(.medium)
}

// Dynamic Type Support
struct AutocaptureText: View {
    let text: String
    let style: Font
    
    var body: some View {
        Text(text)
            .font(style)
            .dynamicTypeSize(.medium ... .large)
    }
}
```

### Spacing System
```swift
// Consistent Spacing
extension CGFloat {
    static let autocaptureSpacingXS: CGFloat = 4
    static let autocaptureSpacingS: CGFloat = 8
    static let autocaptureSpacingM: CGFloat = 16
    static let autocaptureSpacingL: CGFloat = 24
    static let autocaptureSpacingXL: CGFloat = 32
}
```

### Liquid Glass Implementation (iOS 26)
Use the new `glassBackgroundEffect(in:)` API introduced in iOS 26 to render translucent control chrome that reflects ambient content, while providing a `.thinMaterial` fallback for older OS versions.
```swift
struct GlassToolbar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, .autocaptureSpacingL)
            .padding(.vertical, .autocaptureSpacingM)
            .background(
                Group {
                    if #available(iOS 26, *) {
                        Color.clear.glassBackgroundEffect(in: .rect(cornerRadius: 28))
                    } else {
                        Color.clear.background(.thinMaterial)
                    }
                }
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(Color.white.opacity(0.1))
            }
            .shadow(color: .black.opacity(0.25), radius: 30, y: 16)
    }
}
```

## 🔧 Component Design

### Camera Interface
```swift
struct CameraView: View {
    var body: some View {
        ZStack {
            // Camera preview (full screen)
            CameraPreviewView()
            
            // Overlay controls
            VStack(spacing: .autocaptureSpacingM) {
                // Top controls
                GlassToolbar {
                    HStack(spacing: .autocaptureSpacingM) {
                        SettingsButton()
                        Spacer()
                        FlashButton()
                        FlipCameraButton()
                    }
                }
                .padding(.top, .autocaptureSpacingL)
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: .autocaptureSpacingM) {
                    ZoomSlider()
                    CaptureButton()
                        .ifAvailableiOS26 { view in
                            view.glassBackgroundEffect(in: .capsule)
                        }
                }
                .padding(.bottom, .autocaptureSpacingL)
            }
        }
    }
}
```

extension View {
    @ViewBuilder
    func ifAvailableiOS26<Transformed: View>(@ViewBuilder transform: (Self) -> Transformed) -> some View {
        if #available(iOS 26, *) {
            transform(self)
        } else {
            self
        }
    }
}

### Button Styles
```swift
// Primary Action Button
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.autocaptureButton)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.autocapturePrimary)
                .cornerRadius(12)
        }
    }
}

// Secondary Action Button
struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.autocaptureButton)
                .foregroundColor(.autocapturePrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.autocapturePrimary, lineWidth: 2)
                )
        }
    }
}
```

### Card Components
```swift
struct AutocaptureCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.autocaptureSpacingM)
            .background(Color.autocaptureSecondaryBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
```

## 🎯 User Experience Patterns

### Loading States
```swift
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: .autocaptureSpacingM) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(message)
                .font(.autocaptureCaption)
                .foregroundColor(.autocaptureSecondaryLabel)
        }
        .padding(.autocaptureSpacingL)
        .background(Color.autocaptureBackground.opacity(0.9))
        .cornerRadius(12)
    }
}
```

### Error Handling
```swift
struct ErrorAlert: View {
    let title: String
    let message: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: .autocaptureSpacingM) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.autocaptureError)
            
            Text(title)
                .font(.autocaptureHeadline)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.autocaptureBody)
                .foregroundColor(.autocaptureSecondaryLabel)
                .multilineTextAlignment(.center)
            
            PrimaryButton(title: "Try Again", action: action)
        }
        .padding(.autocaptureSpacingL)
    }
}
```

### Success Feedback
```swift
struct SuccessToast: View {
    let message: String
    
    var body: some View {
        HStack(spacing: .autocaptureSpacingS) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.autocaptureSuccess)
            
            Text(message)
                .font(.autocaptureBody)
                .foregroundColor(.autocaptureLabel)
            
            Spacer()
        }
        .padding(.autocaptureSpacingM)
        .background(Color.autocaptureSuccess.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.autocaptureSuccess.opacity(0.3), lineWidth: 1)
        )
    }
}
```

## 📱 Responsive Design

### Screen Size Adaptation
```swift
struct ResponsiveLayout: View {
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > 400 {
                // iPad or large iPhone layout
                HStack {
                    SidebarView()
                    MainContentView()
                }
            } else {
                // iPhone layout
                VStack {
                    TopBarView()
                    MainContentView()
                    BottomBarView()
                }
            }
        }
    }
}
```

### Orientation Handling
```swift
struct OrientationAwareView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                // Landscape layout
                LandscapeLayout()
            } else {
                // Portrait layout
                PortraitLayout()
            }
        }
    }
}
```

## ♿ Accessibility Design

### VoiceOver Support
```swift
struct AccessibleButton: View {
    let title: String
    let hint: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .accessibilityLabel(title)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
    }
}
```

### Dynamic Type Support
```swift
struct ScalableText: View {
    let text: String
    let style: Font
    
    var body: some View {
        Text(text)
            .font(style)
            .dynamicTypeSize(.medium ... .accessibility3)
            .minimumScaleFactor(0.8)
            .lineLimit(nil)
    }
}
```

### High Contrast Support
```swift
struct HighContrastView: View {
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    
    var body: some View {
        VStack {
            // Content
        }
        .background(
            colorSchemeContrast == .increased 
                ? Color.black 
                : Color.autocaptureBackground
        )
    }
}
```

## 🎨 Animation & Transitions

### Smooth Transitions
```swift
struct SmoothTransition: View {
    @State private var isVisible = false
    
    var body: some View {
        VStack {
            if isVisible {
                ContentView()
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}
```

### Haptic Feedback
```swift
struct HapticButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            Text(title)
        }
    }
}
```

## 🎯 AutoCapture Specific UI Patterns

### Camera Controls
- **Capture Button**: Large, prominent, easily accessible
- **Settings**: Secondary position, clear iconography
- **Flash Control**: Visual state indication
- **Zoom Slider**: Smooth, responsive control

### Editor Interface
- **Layer Panel**: Clear hierarchy, drag-and-drop support
- **Tool Panel**: Icon-based tools, active state indication
- **Canvas**: Maximize editing space, gesture support
- **Export Options**: Clear format and quality choices

### Batch Management
- **Stock Number Input**: Clear, validated input field
- **Progress Indicator**: Real-time progress feedback
- **Batch List**: Organized, searchable, filterable
- **Export Options**: Batch export with progress tracking

---

*Follow these UI/UX design principles to create a professional, intuitive, and accessible user experience for AutoCapture.*
