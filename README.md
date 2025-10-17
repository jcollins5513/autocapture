# 🚀 AutoCapture - Professional iOS Photography App

AutoCapture is a professional iOS photography application that uses advanced computer vision for subject detection, background removal, and AI-generated background compositing. The app targets automotive, real estate, restaurant, and small business industries with specialized workflows and templates.

## 📱 Features

### 🎥 Advanced Camera System
- **Professional Controls**: Manual focus, exposure, white balance, and flash control
- **AI-Powered Subject Detection**: Enhanced detection using Vision Framework
- **Automotive Specialization**: Optimized for vehicle photography with 800+ training images
- **Batch Processing**: Stock number-based batch capture and organization
- **High-Quality Output**: 4K resolution support with <2 second processing

### 🎨 Visual Editor
- **Multi-Layer Compositing**: Unlimited layers with drag-and-drop editing
- **File Import Support**: JPEG, JPG, PNG, HEIF, SVG formats
- **Object Manipulation**: Move, scale, rotate, and align objects
- **Real-Time Preview**: Live editing with instant visual feedback
- **Professional Export**: Multiple formats and resolution options

### 🤖 AI Background Generation
- **Category-Based Templates**: Automotive, real estate, restaurant, small business
- **Structured Prompts**: Professional-quality AI prompts with constraints
- **Community Library**: Shared background templates and ratings
- **Quality Control**: High-detail, photo-realistic output standards

### ☁️ Storage & Sync
- **Hybrid Storage**: Local SwiftData + Firebase cloud sync
- **Batch Organization**: Stock number-based image grouping
- **Offline Support**: Full functionality without internet connection
- **Secure Authentication**: Firebase Auth with privacy compliance

## 🏗️ Technical Architecture

### Platform Requirements
- **iOS**: 26.0 or later
- **Devices**: iPhone 15 Pro, iPhone 15 Pro Max
- **Framework**: SwiftUI, SwiftData, Vision, Core Image
- **Backend**: Firebase (Auth, Storage, Firestore)

### Performance Targets
- **Subject Detection**: <2 seconds processing time
- **Memory Usage**: <500MB peak consumption
- **UI Performance**: 60fps smooth interactions
- **Image Resolution**: Up to 4K (3840x2160) support

### Key Technologies
- **Computer Vision**: Vision Framework for subject detection
- **Image Processing**: Core Image with Metal acceleration
- **AI Integration**: Background generation with structured prompts
- **Storage**: SwiftData for local, Firebase for cloud
- **UI**: SwiftUI with modern design principles

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

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 26.0+ development environment
- SwiftLint for code quality
- Firebase project setup

### Installation
1. Clone the repository:
   ```bash
   git clone [repository-url]
   cd autocapture
   ```

2. Install dependencies:
   ```bash
   # Install SwiftLint
   brew install swiftlint
   
   # Install Firebase CLI (optional)
   npm install -g firebase-tools
   ```

3. Configure Firebase:
   - Add `GoogleService-Info.plist` to the project
   - Configure Firebase Authentication, Storage, and Firestore

4. Build and run:
   ```bash
   # Run linting
   ./Scripts/lint.sh
   
   # Build project
   ./Scripts/build.sh
   
   # Run tests
   ./Scripts/test.sh
   ```

## 🧪 Testing

### Test Coverage
- **Overall Coverage**: 80%+ code coverage
- **Services**: 90%+ coverage for business logic
- **ViewModels**: 85%+ coverage for UI logic
- **Models**: 95%+ coverage for data structures

### Running Tests
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

## 🔧 Development

### Code Quality
- **SwiftLint**: Enforced formatting and style consistency
- **Testing**: Comprehensive unit, integration, and UI tests
- **Documentation**: Inline documentation and API docs
- **Error Handling**: Proper error propagation and user feedback

### Development Workflow
1. Create feature branch: `feature/[component-name]`
2. Implement feature with tests
3. Run linting and build scripts
4. Submit pull request with comprehensive testing
5. Merge after code review and validation

### Branch Strategy
- `main`: Production-ready code
- `feature/*`: Feature development branches
- `hotfix/*`: Critical bug fixes
- `release/*`: Release preparation branches

## 📚 Documentation

### Planning Documents
- **[Master Plan](Docs/master-plan.md)**: High-level project roadmap
- **[Granular Plan](Docs/granular-plan.md)**: Detailed development tasks
- **[Requirements](Docs/requirements.md)**: Comprehensive specifications
- **[File Structure](file-structure.md)**: Project organization guide

### Development Guides
- **[AGENTS.md](AGENTS.md)**: AI agents and codex integration
- **[Swift Coding Standards](.cursor/rules/swift-coding-standards.md)**: Code style guidelines
- **[UI Design Principles](.cursor/rules/ui-design-principles.md)**: Design system
- **[Testing Requirements](.cursor/rules/testing-requirements.md)**: Testing standards

### Cursor Commands
- **[Feature Development](.cursor/commands/feature-development.md)**: Development workflow
- **[Testing Workflow](.cursor/commands/testing-workflow.md)**: Testing procedures
- **[Deployment Workflow](.cursor/commands/deployment-workflow.md)**: Release process

## 🎯 Key Features Implementation

### Subject Detection
- Enhanced Vision Framework integration
- Automotive-specific training data
- Quality validation and confidence scoring
- Edge case handling for challenging scenarios

### Visual Editor
- Multi-layer compositing engine
- Real-time rendering with Core Image
- Gesture-based object manipulation
- Professional export capabilities

### AI Background Generation
- Structured prompt templates by category
- Quality control and validation
- Community sharing and rating system
- Performance optimization and caching

### Storage Architecture
- SwiftData for local persistence
- Firebase for cloud synchronization
- Batch organization and metadata
- Secure authentication and privacy

## 🔒 Security & Privacy

### Data Protection
- End-to-end encryption for sensitive data
- On-device AI processing when possible
- Minimal data collection with user consent
- Complete data deletion capability

### Privacy Compliance
- GDPR and CCPA compliance
- Clear privacy policy and data usage
- Granular privacy settings
- Audit trail for data access

## 📊 Performance Metrics

### Processing Performance
- Subject detection: <2 seconds average
- Background removal: <3 seconds average
- AI generation: <10 seconds average
- Image export: <5 seconds for 4K

### Quality Metrics
- <0.1% crash rate target
- 80%+ test coverage
- 60fps UI performance
- <500MB memory usage

## 🚀 Deployment

### App Store Preparation
- App icons and screenshots
- Privacy policy and terms of service
- Age rating and content rights
- Marketing materials and descriptions

### Release Process
- TestFlight beta testing
- App Store submission
- Performance monitoring
- User feedback collection

## 🤝 Contributing

### Development Guidelines
- Follow Swift coding standards
- Write comprehensive tests
- Update documentation
- Ensure accessibility compliance
- Maintain performance requirements

### Code Review Process
- Automated testing and linting
- Peer review for all changes
- Performance validation
- Security review for sensitive features

## 📞 Support

### Documentation
- Comprehensive user guides
- API documentation
- Troubleshooting guides
- FAQ and best practices

### Community
- GitHub issues for bug reports
- Feature request discussions
- Community background sharing
- User feedback integration

---

## 🎉 Getting Started with Development

1. **Read the Documentation**: Start with the master plan and requirements
2. **Set Up Environment**: Install Xcode, SwiftLint, and Firebase tools
3. **Run the Scripts**: Use the provided build and test scripts
4. **Follow Guidelines**: Adhere to coding standards and testing requirements
5. **Contribute**: Submit features, fixes, and improvements

---

*AutoCapture is designed to revolutionize professional photography workflows with AI-powered subject detection and background generation. Built for iOS 26+ with modern SwiftUI architecture and comprehensive testing.*
