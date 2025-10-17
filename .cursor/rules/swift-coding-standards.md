---
alwaysApply: true
---
# 📝 Swift Coding Standards for AutoCapture

You are writing Swift code for AutoCapture iOS app. Follow these coding standards for consistency and quality.

## 🏗️ Architecture Patterns

### MVVM Pattern
- **Models**: Data structures and business logic
- **ViewModels**: UI state management and business logic coordination
- **Views**: SwiftUI views with minimal logic
- **Services**: Business logic and external integrations

### Service Layer
- Separate business logic from UI logic
- Use dependency injection for testability
- Implement proper error handling
- Use async/await for asynchronous operations

## 📁 File Organization

### Import Order
```swift
// 1. System frameworks
import SwiftUI
import SwiftData
import AVFoundation

// 2. Third-party dependencies
import Firebase
import FirebaseAuth

// 3. Local project files
import AutoCaptureModels
import AutoCaptureServices
```

### Class Structure
```swift
class ServiceName {
    // MARK: - Properties
    private let dependency: DependencyType
    
    // MARK: - Initialization
    init(dependency: DependencyType) {
        self.dependency = dependency
    }
    
    // MARK: - Public Methods
    func publicMethod() async throws -> ResultType {
        // Implementation
    }
    
    // MARK: - Private Methods
    private func privateMethod() {
        // Implementation
    }
}
```

## 🎯 Naming Conventions

### Classes and Protocols
- **Services**: `[Feature]Service` (e.g., `CameraService`)
- **ViewModels**: `[Feature]ViewModel` (e.g., `CameraViewModel`)
- **Views**: `[Feature]View` (e.g., `CameraView`)
- **Models**: `[Feature]` (e.g., `ProcessedImage`)
- **Protocols**: `[Feature]Protocol` or `[Feature]able` (e.g., `CameraProtocol`)

### Methods and Properties
- Use descriptive names that explain intent
- Avoid abbreviations and acronyms
- Use camelCase for properties and methods
- Use PascalCase for types and protocols

### Constants
```swift
// Global constants
private let maxImageSize = CGSize(width: 3840, height: 2160)
private let processingTimeout: TimeInterval = 30.0

// Type-specific constants
enum CameraSettings {
    static let defaultZoomFactor: CGFloat = 1.0
    static let maxZoomFactor: CGFloat = 5.0
}
```

## 🔧 Code Style Guidelines

### Variable Declarations
```swift
// Preferred: Explicit type when not obvious
let imageSize: CGSize = CGSize(width: 1920, height: 1080)
let isProcessing: Bool = false

// Acceptable: Type inference when obvious
let imageSize = CGSize(width: 1920, height: 1080)
let isProcessing = false
```

### Optional Handling
```swift
// Preferred: Guard statements for early returns
guard let image = capturedImage else {
    throw CameraError.photoCaptureFailed
}

// Acceptable: Nil coalescing for default values
let displayName = user.name ?? "Anonymous User"

// Avoid: Force unwrapping unless absolutely certain
let image = capturedImage! // Only in tests or when guaranteed
```

### Error Handling
```swift
// Use Result type for operations that can fail
func processImage(_ image: UIImage) async -> Result<ProcessedImage, ProcessingError> {
    do {
        let processedImage = try await backgroundRemovalService.removeBackground(from: image)
        return .success(processedImage)
    } catch {
        return .failure(.processingFailed(error))
    }
}

// Use throws for simple error propagation
func validateImage(_ image: UIImage) throws {
    guard image.size.width > 0 else {
        throw ValidationError.invalidImageSize
    }
}
```

## 🎨 SwiftUI Guidelines

### View Structure
```swift
struct FeatureView: View {
    // MARK: - Properties
    @StateObject private var viewModel = FeatureViewModel()
    @State private var localState: LocalStateType = .initial
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack {
                // View content
            }
            .navigationTitle("Feature Title")
            .task {
                await viewModel.setup()
            }
        }
    }
    
    // MARK: - Private Views
    private var customView: some View {
        // Custom view implementation
    }
}
```

### State Management
```swift
// Use @StateObject for ViewModels
@StateObject private var viewModel = CameraViewModel()

// Use @State for local view state
@State private var isShowingSettings = false

// Use @Binding for two-way data binding
@Binding var selectedImage: UIImage?

// Use @Environment for shared state
@Environment(\.modelContext) private var modelContext
```

### View Modifiers
```swift
// Group related modifiers
VStack {
    // Content
}
.padding()
.background(Color.blue)
.cornerRadius(8)

// Use custom modifiers for reusability
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 2)
    }
}
```

## 🧪 Testing Guidelines

### Test Structure
```swift
@testable import AutoCapture
import XCTest

final class ServiceNameTests: XCTestCase {
    // MARK: - Properties
    private var service: ServiceName!
    private var mockDependency: MockDependency!
    
    // MARK: - Setup
    override func setUp() {
        super.setUp()
        mockDependency = MockDependency()
        service = ServiceName(dependency: mockDependency)
    }
    
    override func tearDown() {
        service = nil
        mockDependency = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    func testMethodName_GivenCondition_ShouldReturnExpectedResult() async throws {
        // Given
        let input = TestData.validInput
        
        // When
        let result = try await service.method(input)
        
        // Then
        XCTAssertEqual(result, expectedResult)
    }
}
```

### Mock Objects
```swift
class MockDependency: DependencyProtocol {
    var shouldFail = false
    var capturedInput: InputType?
    
    func method(_ input: InputType) async throws -> ResultType {
        capturedInput = input
        
        if shouldFail {
            throw MockError.simulatedFailure
        }
        
        return MockData.expectedResult
    }
}
```

## 🔒 Security Guidelines

### Data Protection
```swift
// Use secure storage for sensitive data
import Security

class SecureStorage {
    func store(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityError.storageFailed
        }
    }
}
```

### Input Validation
```swift
// Always validate user input
func processUserInput(_ input: String) throws {
    guard !input.isEmpty else {
        throw ValidationError.emptyInput
    }
    
    guard input.count <= maxInputLength else {
        throw ValidationError.inputTooLong
    }
    
    guard input.rangeOfCharacter(from: .alphanumerics) != nil else {
        throw ValidationError.invalidCharacters
    }
}
```

## ⚡ Performance Guidelines

### Memory Management
```swift
// Use weak references to avoid retain cycles
class ViewModel {
    weak var delegate: ViewModelDelegate?
    
    // Use [weak self] in closures
    func performAsyncOperation() {
        Task { [weak self] in
            guard let self = self else { return }
            // Async operation
        }
    }
}
```

### Image Processing
```swift
// Process images on background queue
func processImage(_ image: UIImage) async -> UIImage {
    return await withTaskGroup(of: UIImage.self) { group in
        group.addTask {
            await self.backgroundRemovalService.removeBackground(from: image)
        }
        
        return await group.next() ?? image
    }
}
```

## 📝 Documentation Guidelines

### Code Comments
```swift
/// Removes the background from an image using AI-powered subject detection
/// - Parameter image: The input image to process
/// - Returns: The processed image with background removed
/// - Throws: `BackgroundRemovalError` if processing fails
func removeBackground(from image: UIImage) async throws -> UIImage {
    // Implementation
}
```

### Mark Comments
```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Extensions
// MARK: - Protocols
```

## 🚨 Common Anti-Patterns to Avoid

### Force Unwrapping
```swift
// ❌ Avoid
let image = capturedImage!
let result = service.method()!

// ✅ Preferred
guard let image = capturedImage else {
    throw CameraError.photoCaptureFailed
}
let result = try service.method()
```

### Massive View Controllers
```swift
// ❌ Avoid: Putting all logic in views
struct CameraView: View {
    var body: some View {
        // 200+ lines of complex logic
    }
}

// ✅ Preferred: Use ViewModels
struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    
    var body: some View {
        // Simple view logic
    }
}
```

### Synchronous Operations on Main Thread
```swift
// ❌ Avoid
func processImage(_ image: UIImage) -> UIImage {
    // Heavy processing on main thread
    return processedImage
}

// ✅ Preferred
func processImage(_ image: UIImage) async -> UIImage {
    return await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            let processedImage = heavyProcessing(image)
            continuation.resume(returning: processedImage)
        }
    }
}
```

---

## 🎯 AutoCapture Specific Guidelines

### Camera Service
- Always check camera authorization before setup
- Use proper error handling for camera failures
- Implement proper resource cleanup
- Handle device orientation changes

### Image Processing
- Process images on background queues
- Use Metal acceleration when available
- Implement proper memory management
- Cache processed results appropriately

### Firebase Integration
- Handle network connectivity issues
- Implement proper offline/online state management
- Use secure authentication practices
- Implement proper error handling for API calls

---

*Follow these coding standards to ensure consistent, maintainable, and high-quality Swift code for AutoCapture.*


