# 🤖 AutoCapture AI Agents & Codex Integration

## 🎯 Project Context
AutoCapture is a professional iOS photography application that uses advanced computer vision for subject detection, background removal, and AI-generated background compositing. The app targets automotive, real estate, restaurant, and small business industries.

## 🏗️ Current Architecture
- **Platform**: iOS 26+ (iPhone 15 Pro/Pro Max)
- **Framework**: SwiftUI with SwiftData
- **Computer Vision**: Vision Framework + Core Image
- **Backend**: Firebase (Auth, Storage, Firestore)
- **Processing**: On-device AI with Metal acceleration

## 📁 Project Structure
```
autocapture/
├── autocapture/                    # Main iOS app
│   ├── Models/                     # Data models & SwiftData
│   ├── Services/                   # Business logic services
│   ├── ViewModels/                 # MVVM view models
│   ├── Views/                      # SwiftUI views
│   ├── Utilities/                  # Helper functions
│   └── Resources/                  # Assets & configurations
├── Docs/                          # Documentation
├── Scripts/                       # Build & lint scripts
└── Tests/                         # Unit & integration tests
```

## 🎨 Key Features & Components

### Core Services
- **CameraService**: Advanced camera controls with professional features
- **BackgroundRemovalService**: AI-powered subject detection and background removal
- **CompositionEditorService**: Multi-layer visual editing system
- **BackgroundGenerationService**: AI background generation with structured prompts
- **StorageManager**: Hybrid storage (local + cloud) with batch organization

### Data Models
- **ProcessedImage**: Enhanced with batch IDs, categories, and metadata
- **Composition**: Multi-layer editing projects with layer management
- **UserProfile**: Firebase-integrated user management
- **BackgroundTemplate**: Category-specific AI prompt templates

### UI Components
- **CameraView**: Professional camera interface with batch capture
- **CompositionEditorView**: Visual editor with layer management
- **BackgroundGeneratorView**: AI prompt interface with category selection
- **BatchManagerView**: Stock number-based batch organization

## 🔧 Development Guidelines

### Code Quality Standards
- **SwiftLint**: Enforced formatting and style consistency
- **Testing**: 80%+ coverage for core functionality
- **Documentation**: Comprehensive inline documentation
- **Error Handling**: Proper error propagation and user feedback

### Performance Requirements
- **Subject Detection**: <2 seconds processing time
- **Image Processing**: 4K+ resolution support
- **UI Performance**: 60fps smooth interactions
- **Memory Efficiency**: Optimized for mobile constraints

### Architecture Patterns
- **MVVM**: Model-View-ViewModel for UI logic
- **Service Layer**: Business logic separation
- **Repository Pattern**: Data access abstraction
- **Dependency Injection**: Testable component design

## 🚀 Feature Development Workflow

### 1. Feature Planning
- Create feature branch: `feature/[component-name]`
- Define requirements and acceptance criteria
- Plan UI/UX mockups and user flows
- Identify dependencies and integration points

### 2. Implementation
- Start with data models and services
- Implement ViewModels with business logic
- Create SwiftUI views with proper state management
- Add comprehensive error handling

### 3. Testing & Validation
- Write unit tests for all services and ViewModels
- Create UI tests for critical user flows
- Performance test on target devices (iPhone 15 Pro+)
- Validate against iOS 26+ compatibility

### 4. Integration & Deployment
- Run SwiftLint and fix all issues
- Execute build scripts and validate
- Merge to main after comprehensive testing
- Deploy to TestFlight for beta testing

## 🎯 AI Integration Points

### Background Generation
- **Structured Prompts**: Category-specific templates with constraints
- **Quality Control**: High-detail, photo-realistic output requirements
- **Batch Processing**: Efficient handling of multiple generation requests
- **Caching**: Smart caching for frequently used backgrounds

### Subject Detection Enhancement
- **Automotive Specialization**: 800+ car photo training data
- **Category Detection**: Automatic subject categorization
- **Quality Scoring**: Confidence metrics for detection accuracy
- **Edge Case Handling**: Robust processing for challenging scenarios

### Visual Editor Intelligence
- **Layer Suggestions**: AI-powered composition recommendations
- **Auto-Alignment**: Smart object positioning and alignment
- **Style Matching**: Automatic style consistency across layers
- **Quality Enhancement**: AI-powered image upscaling and enhancement

## 📊 Success Metrics & KPIs

### User Experience
- **Processing Speed**: Average subject detection time
- **User Satisfaction**: App store ratings and reviews
- **Feature Adoption**: Usage analytics for key features
- **Session Duration**: User engagement metrics

### Technical Performance
- **Crash Rate**: <0.1% crash rate target
- **Memory Usage**: Efficient memory management
- **Processing Quality**: Subject detection accuracy
- **Storage Efficiency**: Optimal file size and compression

### Business Metrics
- **User Retention**: Monthly active user growth
- **Feature Usage**: Background generation and editor usage
- **Community Engagement**: Background sharing and ratings
- **Conversion**: Free to premium subscription conversion

## 🔒 Security & Privacy

### Data Protection
- **Local Processing**: On-device AI processing when possible
- **Secure Storage**: Encrypted local and cloud storage
- **User Privacy**: Minimal data collection with user consent
- **Compliance**: GDPR and CCPA compliance measures

### Authentication & Authorization
- **Firebase Auth**: Secure user authentication
- **Role-Based Access**: User permission management
- **Session Management**: Secure token handling
- **API Security**: Protected backend communications

## 🚨 Critical Considerations

### Performance Optimization
- **Metal Acceleration**: GPU-accelerated image processing
- **Memory Management**: Efficient resource utilization
- **Background Processing**: Non-blocking UI operations
- **Caching Strategy**: Smart data and image caching

### Error Handling & Recovery
- **Graceful Degradation**: Fallback options for AI failures
- **User Feedback**: Clear error messages and recovery options
- **Data Recovery**: Robust data backup and restoration
- **Network Resilience**: Offline capability and sync recovery

### Scalability & Maintenance
- **Modular Architecture**: Loosely coupled components
- **API Versioning**: Backward compatibility management
- **Feature Flags**: Gradual feature rollout capability
- **Monitoring**: Comprehensive logging and analytics

---

## 📞 Support & Communication

### Development Team
- **Lead Developer**: iOS architecture and SwiftUI expertise
- **AI Specialist**: Computer vision and background generation
- **UI/UX Designer**: User experience and visual design
- **QA Engineer**: Testing and quality assurance

### Tools & Resources
- **Xcode**: Primary development environment
- **Firebase Console**: Backend management and monitoring
- **TestFlight**: Beta testing and user feedback
- **App Store Connect**: Production deployment and analytics

### Documentation
- **API Documentation**: Comprehensive service documentation
- **User Guides**: Feature usage and best practices
- **Developer Docs**: Architecture and integration guides
- **Troubleshooting**: Common issues and solutions

---

*This document serves as the central reference for AI agents and codex integration. All development decisions should align with the principles and guidelines outlined above.*
