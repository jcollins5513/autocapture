import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - Liquid Glass primitives

struct LiquidGlass: ViewModifier {
    var tint: Color = .clear
    var cornerRadius: CGFloat = 20
    var strokeOpacity: Double = 0.18
    func body(content: Content) -> some View {
        content
            .background(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(strokeOpacity), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .background(tint.opacity(tint == .clear ? 0 : 0.18))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
extension View {
    func liquidGlass(tint: Color = .clear, cornerRadius: CGFloat = 20) -> some View {
        modifier(LiquidGlass(tint: tint, cornerRadius: cornerRadius))
    }
}

// MARK: - Symbols (SF Symbols wrapper)

struct LGSymbol: View {
    let name: String
    var size: CGFloat = 20
    var weight: Font.Weight = .semibold
    var body: some View {
        Image(systemName: name)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: size, weight: weight))
    }
}

// MARK: - Cards

struct LGCard: View {
    var title: String? = nil
    var subtitle: String? = nil
    var leadingSymbol: String? = nil
    var tint: Color = .clear
    var content: () -> AnyView
    init(title: String? = nil,
         subtitle: String? = nil,
         leadingSymbol: String? = nil,
         tint: Color = .clear,
         @ViewBuilder content: @escaping () -> some View) {
        self.title = title
        self.subtitle = subtitle
        self.leadingSymbol = leadingSymbol
        self.tint = tint
        self.content = { AnyView(content()) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || subtitle != nil || leadingSymbol != nil {
                HStack(spacing: 10) {
                    if let leadingSymbol { LGSymbol(name: leadingSymbol, size: 18) }
                    VStack(alignment: .leading, spacing: 2) {
                        if let title { Text(title).font(.headline) }
                        if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 0)
                }
            }
            content()
        }
        .padding(16)
        .liquidGlass(tint: tint)
    }
}

struct LGCardFullHeight<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                content
            }
            .padding(padding)
        }
        .scrollIndicators(.hidden)
        .background(.ultraThinMaterial)
        .ignoresSafeArea()
    }
}

struct LGCardHalfHeight<Content: View>: View {
    var minHeight: CGFloat = 220
    var maxHeight: CGFloat = 520
    @ViewBuilder var content: Content
    @State private var detent: CGFloat = 0.5
    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(.secondary)
                .frame(width: 44, height: 5)
                .padding(.top, 8)
            content
                .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: minHeight, maxHeight: maxHeight)
        .liquidGlass()
    }
}

// MARK: - Sheets & Presentations

struct LGSheet<Content: View>: ViewModifier {
    @Binding var isPresented: Bool
    var detents: Set<PresentationDetent> = [.medium, .large]
    var cornerRadius: CGFloat = 20
    @ViewBuilder var sheet: () -> Content
    func body(content: ContentOf<Self>) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                sheet()
                    .presentationDetents(detents)
                    .presentationCornerRadius(cornerRadius)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
    }
}
extension View {
    func lgSheet<SheetContent: View>(isPresented: Binding<Bool>,
                                     detents: Set<PresentationDetent> = [.medium, .large],
                                     cornerRadius: CGFloat = 20,
                                     @ViewBuilder content: @escaping () -> SheetContent) -> some View {
        modifier(LGSheet(isPresented: isPresented, detents: detents, cornerRadius: cornerRadius, sheet: content))
    }
}

// MARK: - Progress

struct LGProgress: View {
    var value: Double? = nil
    var label: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            if let value {
                ProgressView(value: value)
                    .progressViewStyle(.linear)
            } else {
                ProgressView().progressViewStyle(.circular)
            }
            if let label { Text(label).font(.subheadline).foregroundStyle(.secondary) }
        }
        .padding(12)
        .liquidGlass(cornerRadius: 14)
    }
}

// MARK: - TextField & ColorPicker

struct LGTextField: View {
    var title: String
    @Binding var text: String
    var systemImage: String? = nil
    var body: some View {
        HStack(spacing: 10) {
            if let systemImage { LGSymbol(name: systemImage, size: 16) }
            TextField(title, text: $text)
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled()
        }
        .padding(14)
        .liquidGlass(cornerRadius: 16)
    }
}

struct LGColorPicker: View {
    var title: String
    @Binding var color: Color
    var body: some View {
        HStack {
            ColorPicker(title, selection: $color, supportsOpacity: true)
            Spacer()
            Circle().fill(color).frame(width: 20, height: 20)
        }
        .padding(14)
        .liquidGlass(cornerRadius: 16)
    }
}

// MARK: - Lists & Menus

struct LGList<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        List {
            content
                .listRowBackground(.thinMaterial)
        }
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
    }
}

struct LGMenu<Label: View>: View {
    var actions: () -> AnyView
    var label: () -> Label
    init(@ViewBuilder actions: @escaping () -> some View,
         @ViewBuilder label: @escaping () -> Label) {
        self.actions = { AnyView(actions()) }
        self.label = label
    }
    var body: some View {
        Menu { actions() } label: { label() }
            .menuStyle(.automatic)
    }
}

// MARK: - Navigation & Tab Bars

struct LGNavigation<Content: View>: View {
    @ViewBuilder var content: Content
    var title: String
    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        }
    }
}

struct LGTabBar<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        TabView { content }
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackgroundVisibility(.visible, for: .tabBar)
    }
}

// MARK: - Sidebar (iPad / large screens)

struct LGSidebar<Sidebar: View, Detail: View>: View {
    @ViewBuilder var sidebar: Sidebar
    @ViewBuilder var detail: Detail
    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Browse")
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        } detail: {
            detail
        }
    }
}

// MARK: - Camera (preview + chrome)

struct CameraPreview: UIViewRepresentable {
    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class CameraController: ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    @Published var isConfigured = false

    func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        guard session.canAddOutput(photoOutput) else { return }
        session.addOutput(photoOutput)
        if photoOutput.isHighResolutionCaptureEnabled { /* enabled by default */ }
        if photoOutput.isDepthDataDeliverySupported { photoOutput.isDepthDataDeliveryEnabled = true }
        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning(); DispatchQueue.main.async { self?.isConfigured = true }
        }
    }
}

struct LGCameraHUD: View {
    var capture: () -> Void
    var openGallery: () -> Void
    var toggleSettings: () -> Void
    @State private var showMenu = false
    var body: some View {
        VStack {
            HStack {
                LGMenu {
                    Button("Grid") { }
                    Button("Flash Auto") { }
                    Button("RAW Off") { }
                } label: {
                    LGSymbol(name: "gearshape")
                        .padding(10)
                        .liquidGlass(cornerRadius: 14)
                }
                Spacer()
                Button(action: toggleSettings) {
                    LGSymbol(name: "slider.horizontal.3")
                        .padding(10)
                        .liquidGlass(cornerRadius: 14)
                }
            }
            .padding([.top, .horizontal])

            Spacer()

            HStack(spacing: 18) {
                Button(action: openGallery) {
                    LGSymbol(name: "photo.on.rectangle")
                        .padding(14)
                        .liquidGlass(cornerRadius: 18)
                }
                Button(action: capture) {
                    Circle()
                        .fill(.thinMaterial)
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 4))
                        .frame(width: 80, height: 80)
                        .shadow(radius: 10)
                }
                Button(action: { showMenu.toggle() }) {
                    LGSymbol(name: "sparkles")
                        .padding(14)
                        .liquidGlass(cornerRadius: 18)
                }
            }
            .padding(.bottom, 20)
            .safeAreaPadding(.bottom, 10) // home indicator clearance
        }
        .foregroundStyle(.primary)
    }
}

struct LGCameraView: View {
    @StateObject private var camera = CameraController()
    @State private var showActions = false
    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            // Top/bottom glass chrome
            LinearGradient(colors: [.black.opacity(0.3), .clear], startPoint: .top, endPoint: .center)
                .ignoresSafeArea(edges: .top)
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)

            LGCameraHUD(capture: { /* hook capture */ },
                        openGallery: { showActions = true },
                        toggleSettings: { showActions = true })
        }
        .task { if !camera.isConfigured { camera.configure() } }
    }
}

// MARK: - Activity View (Share Sheet wrapper)

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Example screens to compose everything

struct ComponentsShowcase: View {
    @State private var search = ""
    @State private var color: Color = .purple
    @State private var showSheet = false
    @State private var progress: Double = 0.4

    var body: some View {
        LGNavigation(title: "Autocapture") {
            LGTabBar {
                // Tab 1: Dashboard
                VStack(spacing: 16) {
                    LGTextField(title: "Search projects, vehicles...", text: $search, systemImage: "magnifyingglass")

                    LGCard(title: "Quick Actions", leadingSymbol: "bolt.fill", tint: .purple) {
                        HStack {
                            Button { showSheet = true } label: {
                                Label("New Capture", systemImage: "camera.fill")
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .liquidGlass(cornerRadius: 14)
                            }
                            Spacer()
                            LGColorPicker(title: "Accent", color: $color)
                        }
                    }

                    LGCard(title: "Processing", subtitle: "Uploading 12 assets") {
                        LGProgress(value: progress, label: "42%")
                    }

                    LGList {
                        Section("Recent") {
                            ForEach(0..<6) { i in
                                HStack {
                                    LGSymbol(name: "car.fill")
                                    Text("VIN #
									
        
	•	Liquid Glass primitives (liquidGlass modifier) with tint/stroke, safe to use on any view.
	•	Cards: generic LGCard, LGCardFullHeight, LGCardHalfHeight (bottom-sheet style with grabber).
	•	Sheets: lgSheet modifier using .presentationDetents, glass background.
	•	Progress: LGProgress (linear/circular).
	•	Inputs: LGTextField (icon + field on glass), LGColorPicker.
	•	Lists/Menus: LGList with material rows, LGMenu wrapper.
	•	Navigation/Tab bars: LGNavigation, LGTabBar with translucent bars.
	•	Sidebar: LGSidebar (iPad split view).
	•	Camera: lightweight CameraPreview + CameraController + LGCameraHUD + LGCameraView (depth enabled if supported).
	•	Activity (Share) sheet wrapper.
	•	A ComponentsShowcase screen to see everything together.

Use ComponentsShowcase() as a starting point. Replace the camera callbacks with your capture pipeline and hook in your subject-lift/background-gen actions. The liquidGlass modifier is intentionally built on .thinMaterial/.ultraThinMaterial so it runs well today and reads “Liquid Glass.” When Apple exposes a dedicated material, swap it in one place.