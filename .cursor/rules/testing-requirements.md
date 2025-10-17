---
alwaysApply: true
---
# 🧪 Testing Requirements for AutoCapture

You are implementing tests for AutoCapture iOS app. Follow these comprehensive testing requirements.

## 📋 Testing Strategy Overview

### Test Coverage Requirements
- **Overall Coverage**: 80%+ code coverage
- **Services**: 90%+ coverage for business logic
- **ViewModels**: 85%+ coverage for UI logic
- **Models**: 95%+ coverage for data structures
- **Utilities**: 90%+ coverage for helper functions

### Test Types Required
- **Unit Tests**: Individual component testing
- **Integration Tests**: Service integration testing
- **UI Tests**: User interface workflow testing
- **Performance Tests**: Speed and memory optimization
- **Accessibility Tests**: VoiceOver and accessibility compliance

## 🏗️ Unit Testing Standards

### Test File Organization
```
Tests/
├── UnitTests/
│   ├── Services/
│   │   ├── CameraServiceTests.swift
│   │   ├── BackgroundRemovalServiceTests.swift
│   │   ├── CompositionEditorServiceTests.swift
│   │   └── BackgroundGenerationServiceTests.swift
│   ├── ViewModels/
│   │   ├── CameraViewModelTests.swift
│   │   ├── CompositionEditorViewModelTests.swift
│   │   └── BackgroundGeneratorViewModelTests.swift
│   ├── Models/
│   │   ├── ProcessedImageTests.swift
│   │   ├── CompositionTests.swift
│   │   └── UserProfileTests.swift
│   └── Utilities/
│       ├── ImageProcessingExtensionsTests.swift
│       └── ValidationHelpersTests.swift
```

### Test Structure Template
```swift
@testable import AutoCapture
import XCTest

final class ServiceNameTests: XCTestCase {
    // MARK: - Properties
    private var sut: ServiceName! // System Under Test
    private var mockDependency: MockDependency!
    
    // MARK: - Setup
    override func setUp() {
        super.setUp()
        mockDependency = MockDependency()
        sut = ServiceName(dependency: mockDependency)
    }
    
    override func tearDown() {
        sut = nil
        mockDependency = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    func testMethodName_GivenValidInput_ShouldReturnExpectedResult() async throws {
        // Given
        let input = TestData.validInput
        let expectedResult = TestData.expectedResult
        
        // When
        let result = try await sut.method(input)
        
        // Then
        XCTAssertEqual(result, expectedResult)
    }
    
    func testMethodName_GivenInvalidInput_ShouldThrowError() async {
        // Given
        let invalidInput = TestData.invalidInput
        
        // When & Then
        do {
            _ = try await sut.method(invalidInput)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is ExpectedErrorType)
        }
    }
}
```

### Mock Implementation Standards
```swift
class MockDependency: DependencyProtocol {
    // MARK: - Properties
    var shouldFail = false
    var capturedInput: InputType?
    var mockResult: ResultType = TestData.defaultResult
    
    // MARK: - Mock Configuration
    func configureMock(shouldFail: Bool = false, result: ResultType? = nil) {
        self.shouldFail = shouldFail
        if let result = result {
            self.mockResult = result
        }
    }
    
    // MARK: - Protocol Implementation
    func method(_ input: InputType) async throws -> ResultType {
        capturedInput = input
        
        if shouldFail {
            throw MockError.simulatedFailure
        }
        
        return mockResult
    }
}
```

## 🔗 Integration Testing Requirements

### Firebase Integration Tests
```swift
final class FirebaseIntegrationTests: XCTestCase {
    private var authService: FirebaseAuthService!
    private var storageService: FirebaseStorageService!
    
    override func setUp() {
        super.setUp()
        // Configure test Firebase project
        authService = FirebaseAuthService()
        storageService = FirebaseStorageService()
    }
    
    func testUserAuthentication_GivenValidCredentials_ShouldAuthenticateUser() async throws {
        // Given
        let email = "test@example.com"
        let password = "testPassword123"
        
        // When
        let result = try await authService.signIn(email: email, password: password)
        
        // Then
        XCTAssertNotNil(result.user)
        XCTAssertEqual(result.user.email, email)
    }
    
    func testImageUpload_GivenValidImage_ShouldUploadSuccessfully() async throws {
        // Given
        let image = TestData.sampleImage
        let path = "test/images/sample.jpg"
        
        // When
        let url = try await storageService.uploadImage(image, to: path)
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url.absoluteString.contains(path))
    }
}
```

### Camera Integration Tests
```swift
final class CameraIntegrationTests: XCTestCase {
    private var cameraService: CameraService!
    private var backgroundRemovalService: BackgroundRemovalService!
    
    func testCaptureAndProcess_GivenValidSubject_ShouldProcessSuccessfully() async throws {
        // Given
        let testImage = TestData.sampleImageWithSubject
        
        // When
        let processedImage = try await backgroundRemovalService.removeBackground(from: testImage)
        
        // Then
        XCTAssertNotNil(processedImage)
        XCTAssertNotEqual(processedImage, testImage)
        // Additional validation for background removal quality
    }
}
```

## 📱 UI Testing Requirements

### UI Test Structure
```swift
final class AutoCaptureUITests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    func testCompleteCaptureWorkflow() {
        // Given: App is launched
        
        // When: User captures and processes image
        app.buttons["Capture"].tap()
        app.buttons["Process"].tap()
        
        // Then: Image should be processed successfully
        XCTAssertTrue(app.staticTexts["Processing Complete"].exists)
    }
    
    func testVisualEditorFunctionality() {
        // Given: User has a processed image
        navigateToEditor()
        
        // When: User adds background and adjusts layers
        app.buttons["Add Background"].tap()
        app.buttons["Layer 1"].tap()
        
        // Then: Changes should be reflected
        XCTAssertTrue(app.buttons["Layer 1"].exists)
    }
}
```

### Accessibility Testing
```swift
final class AccessibilityTests: XCTestCase {
    private var app: XCUIApplication!
    
    func testVoiceOverNavigation() {
        // Given: App is launched with VoiceOver
        app.launchArguments = ["--voiceover-testing"]
        app.launch()
        
        // When: User navigates with VoiceOver
        let captureButton = app.buttons["Capture"]
        captureButton.tap()
        
        // Then: VoiceOver should announce the button
        XCTAssertTrue(captureButton.isAccessibilityElement)
        XCTAssertNotNil(captureButton.accessibilityLabel)
    }
    
    func testDynamicTypeSupport() {
        // Given: App is launched with large text
        app.launchArguments = ["--dynamic-type-large"]
        app.launch()
        
        // When: User views text content
        let titleText = app.staticTexts["AutoCapture"]
        
        // Then: Text should be readable
        XCTAssertTrue(titleText.exists)
        XCTAssertTrue(titleText.isHittable)
    }
}
```

## ⚡ Performance Testing Requirements

### Processing Performance Tests
```swift
final class PerformanceTests: XCTestCase {
    func testSubjectDetectionPerformance() {
        // Given
        let testImage = TestData.sampleImageWithSubject
        let backgroundRemovalService = BackgroundRemovalService()
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let expectation = expectation(description: "Processing complete")
        Task {
            _ = try await backgroundRemovalService.removeBackground(from: testImage)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(processingTime, 2.0, "Subject detection should complete in under 2 seconds")
    }
    
    func testMemoryUsageDuringProcessing() {
        // Given
        let testImage = TestData.largeImage
        let backgroundRemovalService = BackgroundRemovalService()
        
        // When
        let initialMemory = getMemoryUsage()
        
        let expectation = expectation(description: "Processing complete")
        Task {
            _ = try await backgroundRemovalService.removeBackground(from: testImage)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0)
        let peakMemory = getMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        
        // Then
        XCTAssertLessThan(memoryIncrease, 100_000_000, "Memory usage should not increase by more than 100MB")
    }
}
```

### UI Performance Tests
```swift
final class UIPerformanceTests: XCTestCase {
    func testScrollPerformance() {
        // Given
        let app = XCUIApplication()
        app.launch()
        
        // When
        let scrollView = app.scrollViews.firstMatch
        let startTime = CFAbsoluteTimeGetCurrent()
        
        scrollView.swipeUp()
        scrollView.swipeUp()
        scrollView.swipeUp()
        
        let scrollTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(scrollTime, 1.0, "Scrolling should be smooth and responsive")
    }
}
```

## 🧪 Test Data Management

### Test Data Factory
```swift
enum TestData {
    // Images
    static let sampleImage: UIImage = {
        // Create or load test image
        return UIImage(named: "test-image") ?? createTestImage()
    }()
    
    static let sampleImageWithSubject: UIImage = {
        // Create image with clear subject for testing
        return UIImage(named: "test-subject-image") ?? createTestSubjectImage()
    }()
    
    // User Data
    static let validUser = UserProfile(
        id: "test-user-id",
        email: "test@example.com",
        name: "Test User"
    )
    
    // Error Cases
    static let invalidInput = "invalid-input"
    static let emptyInput = ""
    
    // Expected Results
    static let expectedResult = "expected-result"
    
    // Helper Methods
    private static func createTestImage() -> UIImage {
        // Create test image programmatically
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
```

### Mock Data Generators
```swift
class MockDataGenerator {
    static func generateProcessedImage() -> ProcessedImage {
        return ProcessedImage(
            image: TestData.sampleImage,
            batchId: "TEST-001",
            category: .automotive,
            captureDate: Date()
        )
    }
    
    static func generateComposition() -> Composition {
        let composition = Composition()
        composition.addLayer(MockDataGenerator.generateLayer())
        return composition
    }
    
    static func generateLayer() -> CompositionLayer {
        return CompositionLayer(
            image: TestData.sampleImage,
            position: CGPoint(x: 0, y: 0),
            scale: 1.0,
            rotation: 0.0,
            opacity: 1.0
        )
    }
}
```

## 🔍 Test Validation Standards

### Assertion Patterns
```swift
// Equality Assertions
XCTAssertEqual(actual, expected, "Description of what failed")

// Nil Assertions
XCTAssertNotNil(value, "Value should not be nil")
XCTAssertNil(value, "Value should be nil")

// Boolean Assertions
XCTAssertTrue(condition, "Condition should be true")
XCTAssertFalse(condition, "Condition should be false")

// Error Assertions
XCTAssertThrowsError(try methodThatThrows()) { error in
    XCTAssertTrue(error is ExpectedErrorType)
}

// Async Assertions
await XCTAssertNoThrow(try await asyncMethod())
await XCTAssertThrowsError(try await failingAsyncMethod())
```

### Performance Validation
```swift
func validatePerformance<T>(_ operation: () throws -> T, 
                           maxTime: TimeInterval, 
                           file: StaticString = #file, 
                           line: UInt = #line) throws -> T {
    let startTime = CFAbsoluteTimeGetCurrent()
    let result = try operation()
    let executionTime = CFAbsoluteTimeGetCurrent() - startTime
    
    XCTAssertLessThan(executionTime, maxTime, 
                     "Operation took \(executionTime)s, expected less than \(maxTime)s",
                     file: file, line: line)
    
    return result
}
```

## 🚀 Test Execution Workflow

### Pre-Commit Testing
```bash
# Run all tests
./Scripts/test.sh

# Run specific test suites
./Scripts/test.sh unit
./Scripts/test.sh integration
./Scripts/test.sh ui
./Scripts/test.sh performance

# Generate coverage report
./Scripts/test.sh coverage
```

### CI/CD Integration
```yaml
# GitHub Actions example
- name: Run Tests
  run: |
    xcodebuild test \
      -scheme AutoCapture \
      -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
      -enableCodeCoverage YES
      
- name: Generate Coverage Report
  run: |
    xcrun xccov view --report DerivedData/Logs/Test/*.xcresult
```

---

## 🎯 AutoCapture Specific Testing

### Camera Service Testing
- Test camera authorization flow
- Test capture functionality
- Test camera controls (zoom, focus, flash)
- Test error handling for camera failures
- Test device compatibility

### Background Removal Testing
- Test subject detection accuracy
- Test edge case handling
- Test performance with different image sizes
- Test quality validation
- Test automotive specialization

### Visual Editor Testing
- Test layer management operations
- Test object manipulation
- Test file import/export
- Test undo/redo functionality
- Test performance with many layers

### AI Integration Testing
- Test background generation requests
- Test prompt template processing
- Test error handling for AI failures
- Test caching and performance
- Test community features

---

*Follow these testing requirements to ensure AutoCapture meets all quality, performance, and reliability standards.*


