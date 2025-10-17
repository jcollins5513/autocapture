---
alwaysApply: false
---
# 🧪 Testing Workflow for AutoCapture

You are implementing testing for AutoCapture iOS app features. Follow this comprehensive testing approach.

## 📋 Testing Strategy Overview

### Test Types Required
- **Unit Tests**: Individual component testing
- **Integration Tests**: Service integration testing
- **UI Tests**: User interface workflow testing
- **Performance Tests**: Speed and memory optimization testing
- **Accessibility Tests**: VoiceOver and accessibility compliance

## 🏗️ Unit Testing Requirements

### Service Testing
- [ ] Test all business logic services in `autocapture/Services/`
- [ ] Mock external dependencies (Firebase, AI services)
- [ ] Test error handling and edge cases
- [ ] Validate input/output data transformations
- [ ] Test async operations with proper expectations

### ViewModel Testing
- [ ] Test state management and UI logic
- [ ] Mock service dependencies
- [ ] Test user interaction handling
- [ ] Validate data binding and updates
- [ ] Test error state management

### Model Testing
- [ ] Test data model validation
- [ ] Test SwiftData persistence operations
- [ ] Test data transformation methods
- [ ] Validate business rule enforcement
- [ ] Test serialization/deserialization

## 🔗 Integration Testing Requirements

### Firebase Integration
- [ ] Test authentication flows
- [ ] Test storage upload/download operations
- [ ] Test Firestore data synchronization
- [ ] Test offline/online state handling
- [ ] Validate error handling and retry logic

### Camera Integration
- [ ] Test capture functionality
- [ ] Test subject detection accuracy
- [ ] Test background removal processing
- [ ] Test batch processing workflows
- [ ] Validate performance requirements

### AI Integration
- [ ] Test background generation requests
- [ ] Test prompt template processing
- [ ] Test result caching and retrieval
- [ ] Test error handling for AI failures
- [ ] Validate quality requirements

## 📱 UI Testing Requirements

### User Workflows
- [ ] Test complete capture-to-export workflow
- [ ] Test visual editor functionality
- [ ] Test batch management operations
- [ ] Test user authentication flows
- [ ] Test settings and preferences

### Device Compatibility
- [ ] Test on iPhone 15 Pro
- [ ] Test on iPhone 15 Pro Max
- [ ] Test iOS 17+ compatibility
- [ ] Test different screen orientations
- [ ] Test accessibility features

## ⚡ Performance Testing Requirements

### Processing Performance
- [ ] Subject detection: <2 seconds
- [ ] Background removal: <3 seconds
- [ ] AI generation: <10 seconds
- [ ] Image export: <5 seconds
- [ ] App startup: <3 seconds

### Memory Performance
- [ ] Peak memory usage: <500MB
- [ ] Memory leaks detection
- [ ] Efficient image processing
- [ ] Proper resource cleanup
- [ ] Background memory management

### UI Performance
- [ ] 60fps smooth interactions
- [ ] Responsive touch handling
- [ ] Smooth animations and transitions
- [ ] Efficient list scrolling
- [ ] Real-time preview performance

## ♿ Accessibility Testing Requirements

### VoiceOver Support
- [ ] All UI elements have accessibility labels
- [ ] Navigation works with VoiceOver
- [ ] Custom controls are accessible
- [ ] Error messages are announced
- [ ] Dynamic content updates are announced

### Other Accessibility Features
- [ ] Dynamic Type support
- [ ] High Contrast mode support
- [ ] Reduced Motion preferences
- [ ] Switch Control compatibility
- [ ] Voice Control compatibility

## 🧪 Test Implementation Guidelines

### Test File Organization
```
Tests/
├── UnitTests/
│   ├── Services/
│   │   ├── CameraServiceTests.swift
│   │   ├── BackgroundRemovalServiceTests.swift
│   │   └── ...
│   ├── ViewModels/
│   │   ├── CameraViewModelTests.swift
│   │   ├── CompositionEditorViewModelTests.swift
│   │   └── ...
│   └── Models/
│       ├── ProcessedImageTests.swift
│       ├── CompositionTests.swift
│       └── ...
├── IntegrationTests/
│   ├── FirebaseIntegrationTests.swift
│   ├── CameraIntegrationTests.swift
│   └── ...
└── PerformanceTests/
    ├── ImageProcessingBenchmarks.swift
    ├── MemoryUsageTests.swift
    └── ...
```

### Test Naming Conventions
- **Test Methods**: `test[FunctionName]_[Scenario]_[ExpectedResult]`
- **Test Classes**: `[ComponentName]Tests`
- **Test Suites**: `[FeatureName]TestSuite`

### Mocking Guidelines
- Mock external dependencies (Firebase, AI services)
- Use dependency injection for testable components
- Create realistic test data
- Test both success and failure scenarios
- Validate mock interactions

## 📊 Test Coverage Requirements

### Coverage Targets
- **Services**: 90%+ coverage
- **ViewModels**: 85%+ coverage
- **Models**: 95%+ coverage
- **Utilities**: 90%+ coverage
- **Overall**: 80%+ coverage

### Coverage Validation
- Run coverage analysis with each build
- Identify and address low-coverage areas
- Ensure critical paths are fully tested
- Document any uncovered code with justification
- Review coverage reports regularly

## 🚀 Test Execution Workflow

### Pre-Commit Testing
- [ ] Run unit tests: `Scripts/test.sh unit`
- [ ] Run integration tests: `Scripts/test.sh integration`
- [ ] Run performance tests: `Scripts/test.sh performance`
- [ ] Validate test coverage: `Scripts/test.sh coverage`
- [ ] All tests must pass before commit

### CI/CD Testing
- [ ] Automated test execution on pull requests
- [ ] Performance regression testing
- [ ] Device compatibility testing
- [ ] Accessibility validation
- [ ] Coverage threshold enforcement

### Manual Testing
- [ ] User acceptance testing
- [ ] Edge case validation
- [ ] Device-specific testing
- [ ] Real-world scenario testing
- [ ] Accessibility user testing

## 🐛 Bug Testing & Validation

### Bug Reproduction
- [ ] Create minimal reproduction cases
- [ ] Document steps to reproduce
- [ ] Identify root cause
- [ ] Create regression tests
- [ ] Validate fix effectiveness

### Regression Testing
- [ ] Test all related functionality
- [ ] Validate performance impact
- [ ] Check for new edge cases
- [ ] Ensure no new bugs introduced
- [ ] Update test suite as needed

---

## 🎯 AutoCapture Specific Testing

### Camera Features
- Test subject detection accuracy across categories
- Validate background removal quality
- Test batch processing efficiency
- Verify camera control functionality
- Test edge cases (low light, motion blur)

### Visual Editor
- Test layer management operations
- Validate object manipulation accuracy
- Test file import/export functionality
- Verify undo/redo operations
- Test performance with many layers

### AI Features
- Test prompt template processing
- Validate background generation quality
- Test caching and performance
- Verify error handling for AI failures
- Test community background features

### Storage & Sync
- Test local storage operations
- Validate cloud synchronization
- Test offline/online transitions
- Verify data integrity
- Test conflict resolution

---

*Follow this testing workflow to ensure AutoCapture meets all quality and performance requirements.*


